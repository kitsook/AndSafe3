import 'package:andsafe/models/note.dart';
import 'package:andsafe/utils/services/preferences_service.dart';
import 'package:sqflite/sqflite.dart';

class NoteService {
  final Database db;

  NoteService(this.db);

  static const _sqliteMaxVariableNumber = 999;

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
    await db.transaction((txn) => _deleteNote(id, txn));
  }

  Future<List<Note>> getNotes([Set<int> ids = const <int>{}]) async {
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
    List<Map> rows = await db.query(
      'notes',
      where: '_id=?',
      whereArgs: [id],
    );
    return rows.length > 0
        ? Note.fromMap(rows.first as Map<String, dynamic>)
        : null;
  }

  Future<Set<int>> searchNotes(String query) async {
    List<Map> rows = await db.query(
      'searchable',
      columns: [
        'docid',
        "matchinfo(searchable, 'pcx') as info",
      ],
      where: 'searchable match ?',
      whereArgs: [query],
    );
    return rows.map((row) {
      return row['docid'] as int;
    }).toSet();
  }
}
