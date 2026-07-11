import 'package:andsafe/models/note.dart';
import 'package:andsafe/models/signature.dart';
import 'package:andsafe/utils/services/preferences_service.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

const _currentDatabaseVersion = 3;

class DatabaseAdapter {
  Future<Database>? _database;

  DatabaseAdapter() : super() {}

  Future<Database> _getDatabase() {
    _database ??= _init();
    return _database!;
  }

  Future<Database> _init() async {
    String dbFullPath = join(await getDatabasesPath(), 'safe.db');
    return openDatabase(
      dbFullPath,
      onCreate: (db, version) async {
        // create tables on first run
        await db.execute(
            'create table notes (_id integer primary key autoincrement, cat_id integer not null, ' +
                'title text not null, body text not null, salt blob, iv blob, last_update date);');
        await db.execute(
            'create table signature (_id integer primary key autoincrement, plain text, payload text, ' +
                'salt blob, iv blob, ver integer);');

        await db
            .execute('create virtual table searchable ' + 'using fts3 (title)');
        await db.execute(
            'create index idx_notes_title_nocase on notes(title collate nocase);');
        await db.execute(
            'create index idx_notes_last_update on notes(last_update);');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion == 1) {
          // add virtual table for search function
          await db.transaction((txn) async {
            await txn.execute(
                'create virtual table searchable ' + 'using fts3 (title)');
            await txn.rawQuery(
                'insert into searchable (docid, title) select _id, title from notes;');
          });
        }

        // update signature. use KCV concept and only store part of the encrypted payload
        await db.transaction((txn) async {
          await txn.rawQuery(
              'update signature set payload = substr(payload, 1, ' +
                  (signatureKeyCheckValueLengthInByte * 2).toString() +
                  ');');
          await txn.update('signature', {'ver': currentSignatureVer});
        });

        if (oldVersion < 3) {
          await db.transaction((txn) async {
            await txn.execute('drop index if exists idx_notes_title;');
            await txn.execute(
                'create index idx_notes_title_nocase on notes(title collate nocase);');
            await txn.execute(
                'create index idx_notes_last_update on notes(last_update);');
          });
        }
      },
      version: _currentDatabaseVersion,
    );
  }

  Future<Database> getDb() {
    return _getDatabase();
  }

  Future<int> _insertNote(Note note, Transaction txn) async {
    int id = await txn.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await txn.insert('searchable', {'docid': id, 'title': note.title});
    return id;
  }

  Future<int> insertNote(Note note, [Transaction? txn]) async {
    if (txn != null) return _insertNote(note, txn);
    final Database db = await _getDatabase();
    return await db.transaction<int>((txn) => _insertNote(note, txn));
  }

  Future<void> _updateNote(Note note, Transaction txn) async {
    await txn.update(
      'notes',
      note.toMap(),
      where: '_id=?',
      whereArgs: [note.id],
    );
    await txn.update(
      'searchable',
      {'title': note.title},
      where: 'docid=?',
      whereArgs: [note.id],
    );
  }

  Future<void> updateNote(Note note, [Transaction? txn]) async {
    if (txn != null) return _updateNote(note, txn);
    final Database db = await _getDatabase();
    await db.transaction((txn) => _updateNote(note, txn));
  }

  Future<void> _deleteNote(int id, Transaction txn) async {
    await txn.delete(
      'notes',
      where: '_id=?',
      whereArgs: [id],
    );
    await txn.delete(
      'searchable',
      where: 'docid=?',
      whereArgs: [id],
    );
  }

  Future<void> deleteNote(int id, [Transaction? txn]) async {
    if (txn != null) return _deleteNote(id, txn);
    final Database db = await _getDatabase();
    await db.transaction((txn) => _deleteNote(id, txn));
  }

  /// SQLite has a limit on the number of host parameters in a single statement
  /// (SQLITE_MAX_VARIABLE_NUMBER, default 999). Batch queries accordingly.
  static const _sqliteMaxVariableNumber = 999;

  Future<List<Note>> getNotes([Set<int> ids = const <int>{}]) async {
    final Database db = await _getDatabase();
    final String sortBy = await Prefs.getSortBy();
    final bool sortAscending = await Prefs.isSortAscending();

    final String orderBy;
    if (sortBy == PREF_SORT_KEY_TITLE) {
      orderBy = 'title COLLATE NOCASE ${sortAscending ? 'ASC' : 'DESC'}, last_update DESC, _id DESC';
    } else {
      orderBy = 'last_update ${sortAscending ? 'ASC' : 'DESC'}, _id DESC';
    }

    List<Map> rows;
    if (ids.isEmpty) {
      rows = await db.query(
        'notes',
        orderBy: orderBy,
      );
    } else if (ids.length <= _sqliteMaxVariableNumber) {
      rows = await db.query(
        'notes',
        where: '_id IN (${ids.map((_) => '?').join(',')})',
        whereArgs: ids.toList(),
        orderBy: orderBy,
      );
    } else {
      // Batch queries to stay within SQLite parameter limit
      rows = [];
      final idList = ids.toList();
      for (var i = 0; i < idList.length; i += _sqliteMaxVariableNumber) {
        final batch = idList.sublist(
            i,
            i + _sqliteMaxVariableNumber > idList.length
                ? idList.length
                : i + _sqliteMaxVariableNumber);
        final batchRows = await db.query(
          'notes',
          where: '_id IN (${batch.map((_) => '?').join(',')})',
          whereArgs: batch,
          orderBy: orderBy,
        );
        rows.addAll(batchRows);
      }
    }

    final notes = rows
        .map((row) => Note.fromMap(row as Map<String, dynamic>))
        .toList();

    // Re-sort in Dart when results came from multiple batches, since each
    // batch is individually sorted but the merged list is not.
    if (ids.length > _sqliteMaxVariableNumber) {
      notes.sort((a, b) {
        if (sortBy == PREF_SORT_KEY_TITLE) {
          final cmp = a.title.toUpperCase().compareTo(b.title.toUpperCase()) *
              (sortAscending ? 1 : -1);
          if (cmp != 0) return cmp;
          final cmpDate = b.lastUpdate.compareTo(a.lastUpdate);
          if (cmpDate != 0) return cmpDate;
          return b.id!.compareTo(a.id!);
        } else {
          final cmp = a.lastUpdate.compareTo(b.lastUpdate) *
              (sortAscending ? 1 : -1);
          if (cmp != 0) return cmp;
          return b.id!.compareTo(a.id!);
        }
      });
    }

    return notes;
  }

  Future<Note?> getNote(int id) async {
    final Database db = await _getDatabase();
    List<Map> rows = await db.query(
      'notes',
      where: '_id=?',
      whereArgs: [id],
    );
    return rows.length > 0
        ? Note.fromMap(rows.first as Map<String, dynamic>)
        : null;
  }

  Future<bool> isPasswordSet() async {
    final Database db = await _getDatabase();
    List<Map> rows = await db.rawQuery('SELECT COUNT(1) AS num FROM signature');
    if (rows.length == 0) {
      return false;
    }
    return rows[0]['num'] as int == 1;
  }

  Future<void> _generateSignature(Signature sig, Transaction txn) async {
    await txn.delete(
      'signature',
    );
    await txn.insert(
      'signature',
      sig.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> generateSignature(Signature sig, [Transaction? txn]) async {
    if (txn != null) return _generateSignature(sig, txn);
    final Database db = await _getDatabase();
    await db.transaction((txn) => _generateSignature(sig, txn));
  }

  Future<Signature?> getSignature() async {
    final Database db = await _getDatabase();
    List<Map> rows = await db.query(
      'signature',
      limit: 1,
    );
    return rows.length > 0
        ? Signature.fromMap(rows.first as Map<String, dynamic>)
        : null;
  }

  Future<Set<int>> searchNotes(String query) async {
    final Database db = await _getDatabase();
    List<Map> rows = await db.query(
      'searchable',
      columns: [
        'docid',
        "matchinfo(searchable, 'pcx') as info",
      ],
      where: 'searchable match ?',
      whereArgs: [query],
    );
    // TODO order by rank
    return rows.map((row) {
      return row['docid'] as int;
    }).toSet();
  }
}
