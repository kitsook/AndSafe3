import 'package:andsafe/models/note.dart';
import 'package:andsafe/models/signature.dart';
import 'package:andsafe/utils/services/preferences_service.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

DatabaseAdapter adapter = DatabaseAdapter();
const _currentDatabaseVersion = 2;

class DatabaseAdapter {
  late Future<Database> _database;

  DatabaseAdapter() : super() {
    this._database = _init();
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

        await db.execute('create virtual table searchable ' +
            'using fts3 (title)');
        // TODO the original plan was to create an index with upper(title)...
        // but it is not supported by older version of android. so for now,
        // we sort the list after retrieving the notes from db
        // await db.execute('create index idx_notes_title on notes(title, _id)');
        // await db.execute('create index idx_notes_last_update on notes(last_update, _id)');
        await db.execute('create index idx_notes_title on notes(_id)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion == 1) {
          // add virtual table for search function
          await db.transaction((txn) async {
            await txn.execute('create virtual table searchable ' +
                'using fts3 (title)');
            await txn.rawQuery('insert into searchable (docid, title) select _id, title from notes;');
          });
        }

        // update signature. use KCV concept and only store part of the encrypted payload
        await db.transaction((txn) async {
          await txn.rawQuery('update signature set payload = substr(payload, 1, '
          + (signatureKeyCheckValueLengthInByte * 2).toString() + ');');
          await txn.update(
              'signature',
              {'ver': currentSignatureVer});
        });
      },
      version: _currentDatabaseVersion,
    );
  }

  Future<Database> getDb() {
    return this._database;
  }

  Future<void> insertNote(Note note) async {
    final Database db = await this._database;
    int id = await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      'searchable',
      {'docid': id, 'title': note.title}
    );
  }

  Future<void> updateNote(Note note, [Transaction? txn]) async {
    if (txn == null) {
      final Database db = await this._database;

      await db.update(
        'notes',
        note.toMap(),
        where: '_id=?',
        whereArgs: [note.id],
      );
      await db.update(
        'searchable',
        {'title': note.title},
        where: 'docid=?',
        whereArgs: [note.id],
      );
    } else {
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
  }

  Future<void> deleteNote(int id) async {
    final Database db = await this._database;
    await db.delete(
      'notes',
      where: '_id=?',
      whereArgs: [id],
    );
    await db.delete(
      'searchable',
      where: 'docid=?',
      whereArgs: [id],
    );
  }

  Future<List<Note>> getNotes([ Set<int> ids = const <int>{} ]) async {
    final Database db = await this._database;
    final String sortBy = await Prefs.getSortBy();
    final bool sortAscending = await Prefs.isSortAscending();
    List<Map> rows = await db.query(
      'notes',
      // orderBy: sortBy + (sortAscending? ' asc' : ' desc') + ', _id asc',
      orderBy: '_id asc',
    );
    // TODO sort and filter with sql query instead of doing it after retrieving all notes
    final List<Note> notes = rows
      .where((row) => ids.isEmpty || ids.contains(row['_id']))
      .map((row) => Note.fromMap(row as Map<String, dynamic>))
      .toList();
    notes.sort((a, b) {
      if (!sortAscending) {
        var temp = b;
        b = a;
        a = temp;
      }
      if (sortBy == PREF_SORT_KEY_TITLE) {
        return a.title.toUpperCase().compareTo(b.title.toUpperCase());
      }
      return a.lastUpdate.compareTo(b.lastUpdate);
    });
    return notes;
  }

  Future<Note?> getNote(int id) async {
    final Database db = await this._database;
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
    final Database db = await this._database;
    List<Map> rows = await db.rawQuery('SELECT COUNT(1) AS num FROM signature');
    if (rows.length == 0) {
      return false;
    }
    return rows[0]['num'] as int == 1;
  }

  Future<void> generateSignature(Signature sig, [Transaction? txn]) async {
    if (txn == null) {
      final Database db = await this._database;

      await db.delete(
        'signature',
      );
      await db.insert(
        'signature',
        sig.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await txn.delete(
        'signature',
      );
      await txn.insert(
        'signature',
        sig.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<Signature> getSignature() async {
    final Database db = await this._database;
    List<Map> rows = await db.query(
      'signature',
      limit: 1,
    );
    return rows.length > 0
        ? Future<Signature>.value(
            Signature.fromMap(rows.first as Map<String, dynamic>))
        : Future<Signature>.value(null);
  }

  Future<Set<int>> searchNotes(String query) async {
    final Database db = await this._database;
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
