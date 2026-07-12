import 'package:andsafe/models/note.dart';
import 'package:andsafe/utils/services/preferences_service.dart';
import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart';

final _log = Logger('NoteService');

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
    try {
      if (txn != null) return await _insertNote(note, txn);
      return await db.transaction<int>((txn) => _insertNote(note, txn));
    } catch (e, stackTrace) {
      _log.severe('Failed to insert note', e, stackTrace);
      rethrow;
    }
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
    try {
      if (txn != null) {
        await _updateNote(note, txn);
        return;
      }
      await db.transaction((txn) => _updateNote(note, txn));
    } catch (e, stackTrace) {
      _log.severe('Failed to update note with id ${note.id}', e, stackTrace);
      rethrow;
    }
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
    try {
      if (txn != null) {
        await _deleteNote(id, txn);
        return;
      }
      await db.transaction((txn) => _deleteNote(id, txn));
    } catch (e, stackTrace) {
      _log.severe('Failed to delete note with id $id', e, stackTrace);
      rethrow;
    }
  }

  Future<List<Note>> getNotes([Set<int> ids = const <int>{}]) async {
    try {
      final String sortBy = await Prefs.getSortBy();
      final bool sortAscending = await Prefs.isSortAscending();

      final String orderBy;
      if (sortBy == prefSortKeyTitle) {
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
          if (sortBy == prefSortKeyTitle) {
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
    } catch (e, stackTrace) {
      _log.severe('Failed to get notes', e, stackTrace);
      rethrow;
    }
  }

  Future<Note?> getNote(int id) async {
    try {
      List<Map> rows = await db.query(
        'notes',
        where: '_id=?',
        whereArgs: [id],
      );
      return rows.isNotEmpty
          ? Note.fromMap(rows.first as Map<String, dynamic>)
          : null;
    } catch (e, stackTrace) {
      _log.severe('Failed to get note with id $id', e, stackTrace);
      rethrow;
    }
  }

  Future<Set<int>> searchNotes(String query) async {
    try {
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
    } catch (e, stackTrace) {
      _log.severe('Failed to search notes with query "$query"', e, stackTrace);
      rethrow;
    }
  }
}
