import 'dart:typed_data';

import 'package:andsafe/models/note.dart';
import 'package:andsafe/models/signature.dart';
import 'package:andsafe/utils/services/database_service.dart';
import 'package:andsafe/utils/services/preferences_service.dart';

/// A reusable mock DatabaseAdapter that can behave as a fully working in-memory
/// database (useful for integration flow testing) or support manual value overrides
/// and call tracking/spies (useful for unit and widget testing).
class MockDatabaseAdapter extends DatabaseAdapter {
  // In-memory data store
  List<Note> notes = [];
  Signature? signature;
  int nextNoteId = 1;

  // Trackers / Spies
  bool insertNoteCalled = false;
  bool updateNoteCalled = false;
  bool deleteNoteCalled = false;
  Note? lastInsertedNote;
  Note? lastUpdatedNote;
  int? lastDeletedNoteId;

  // Manual Overrides
  Note? _noteToReturn;
  bool _hasNoteOverride = false;

  List<Note>? _notesToReturn;
  bool _hasNotesOverride = false;

  bool? overrideIsPasswordSet;

  Note? get noteToReturn => _noteToReturn;
  set noteToReturn(Note? value) {
    _noteToReturn = value;
    _hasNoteOverride = true;
  }

  List<Note> get notesToReturn => _notesToReturn ?? notes;
  set notesToReturn(List<Note> value) {
    _notesToReturn = value;
    _hasNotesOverride = true;
  }

  /// Resets the mock adapter data store and tracking spies.
  void reset() {
    notes.clear();
    signature = null;
    nextNoteId = 1;
    insertNoteCalled = false;
    updateNoteCalled = false;
    deleteNoteCalled = false;
    lastInsertedNote = null;
    lastUpdatedNote = null;
    lastDeletedNoteId = null;
    _noteToReturn = null;
    _hasNoteOverride = false;
    _notesToReturn = null;
    _hasNotesOverride = false;
    overrideIsPasswordSet = null;
  }

  @override
  Future<bool> isPasswordSet() async {
    if (overrideIsPasswordSet != null) return overrideIsPasswordSet!;
    return signature != null;
  }

  @override
  Future<void> generateSignature(Signature sig, [dynamic txn]) async {
    signature = sig;
  }

  @override
  Future<Signature?> getSignature() async {
    return signature;
  }

  @override
  Future<int> insertNote(Note note) async {
    insertNoteCalled = true;
    final noteWithId = Note(
      note.id ?? nextNoteId++,
      note.categoryId,
      note.title,
      note.body,
      note.salt,
      note.iv,
      note.lastUpdate,
    );
    notes.add(noteWithId);
    lastInsertedNote = noteWithId;
    return noteWithId.id!;
  }

  @override
  Future<void> updateNote(Note note, [dynamic txn]) async {
    updateNoteCalled = true;
    lastUpdatedNote = note;
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      notes[index] = note;
    } else {
      notes.add(note);
    }
  }

  @override
  Future<void> deleteNote(int id) async {
    deleteNoteCalled = true;
    lastDeletedNoteId = id;
    notes.removeWhere((n) => n.id == id);
  }

  @override
  Future<List<Note>> getNotes([Set<int> ids = const <int>{}]) async {
    if (_hasNotesOverride) {
      return _notesToReturn!.where((n) => ids.isEmpty || ids.contains(n.id)).toList();
    }
    final result = notes.where((n) => ids.isEmpty || ids.contains(n.id)).toList();
    final sortBy = await Prefs.getSortBy();
    final sortAscending = await Prefs.isSortAscending();
    result.sort((a, b) {
      if (sortBy == PREF_SORT_KEY_TITLE) {
        return a.title.toUpperCase().compareTo(b.title.toUpperCase()) *
            (sortAscending ? 1 : -1);
      }
      return a.lastUpdate.compareTo(b.lastUpdate) * (sortAscending ? 1 : -1);
    });
    return result;
  }

  @override
  Future<Note?> getNote(int id) async {
    if (_hasNoteOverride) return _noteToReturn;
    final matches = notes.where((n) => n.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<Set<int>> searchNotes(String query) async {
    final cleanQuery = query.replaceAll('*', '').toLowerCase();
    return notes
        .where((n) => n.title.toLowerCase().contains(cleanQuery))
        .map((n) => n.id!)
        .toSet();
  }
}
