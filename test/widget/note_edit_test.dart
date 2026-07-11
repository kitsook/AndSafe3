import 'dart:typed_data';

import 'package:andsafe/l10n/app_localizations.dart';
import 'package:andsafe/models/note.dart';
import 'package:andsafe/models/signature.dart';
import 'package:andsafe/pages/note_edit.dart';
import 'package:andsafe/utils/services/database_service.dart' as db;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A mock DatabaseAdapter that overrides methods used by NoteEdit
/// without connecting to a real database.
class MockDatabaseAdapter extends db.DatabaseAdapter {
  Note? noteToReturn;
  int nextInsertId = 10;
  bool insertNoteCalled = false;
  bool updateNoteCalled = false;
  Note? lastInsertedNote;
  Note? lastUpdatedNote;

  @override
  Future<Note?> getNote(int id) async => noteToReturn;

  @override
  Future<int> insertNote(Note note, [dynamic txn]) async {
    insertNoteCalled = true;
    lastInsertedNote = note;
    return nextInsertId++;
  }

  @override
  Future<void> updateNote(Note note, [dynamic txn]) async {
    updateNoteCalled = true;
    lastUpdatedNote = note;
  }

  @override
  Future<void> deleteNote(int id, [dynamic txn]) async {}

  @override
  Future<List<Note>> getNotes([Set<int> ids = const <int>{}]) async => [];

  @override
  Future<void> generateSignature(Signature sig, [dynamic txn]) async {}

  @override
  Future<Signature?> getSignature() async => null;

  @override
  Future<Set<int>> searchNotes(String query) async => {};

  @override
  Future<bool> isPasswordSet() async => true;
}

void main() {
  late MockDatabaseAdapter mockAdapter;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockAdapter = MockDatabaseAdapter();
  });

  tearDown(() {
  });

  Widget buildTestApp({
    int? noteId,
    Uint8List? password,
    int signatureVer = currentSignatureVer,
    ValueChanged<int?>? onNoteSaved,
    ValueChanged<int?>? onNoteDeleted,
    VoidCallback? onNoteCancelled,
  }) {
    return Provider<db.DatabaseAdapter>.value(
      value: mockAdapter,
      child: MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: NoteEdit(
          id: noteId,
          password: password ?? Uint8List.fromList([1, 2, 3, 4]),
          signatureVer: signatureVer,
          onNoteSaved: onNoteSaved,
          onNoteDeleted: onNoteDeleted,
          onNoteCancelled: onNoteCancelled,
        ),
      ),
    );
  }

  group('NoteEdit - New Note', () {
    testWidgets('renders create note UI with correct title',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(noteId: null));
      await tester.pumpAndSettle();

      // AppBar should show "Create note"
      expect(find.text('Create note'), findsOneWidget);
    });

    testWidgets('shows title and body input fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(noteId: null));
      await tester.pumpAndSettle();

      // Title field with hint
      expect(
        find.text('Title of your note (not encrypted)'),
        findsOneWidget,
      );
      // Body field with hint
      expect(find.text('Notes to be encrypted'), findsOneWidget);
    });

    testWidgets('does not show delete button for new note',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(noteId: null));
      await tester.pumpAndSettle();

      // No delete button for new notes
      expect(find.byIcon(Icons.delete_rounded), findsNothing);
    });

    testWidgets('shows back arrow button', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(noteId: null));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('can enter text in title field', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(noteId: null));
      await tester.pumpAndSettle();

      // Find the title TextFormField by its hint text
      final titleField = find.widgetWithText(
        TextFormField,
        'Title of your note (not encrypted)',
      );
      await tester.enterText(titleField, 'My Test Note');
      await tester.pump();

      expect(find.text('My Test Note'), findsOneWidget);
    });

    testWidgets('can enter text in body field', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(noteId: null));
      await tester.pumpAndSettle();

      final bodyField = find.widgetWithText(
        TextFormField,
        'Notes to be encrypted',
      );
      await tester.enterText(bodyField, 'Secret content here');
      await tester.pump();

      expect(find.text('Secret content here'), findsOneWidget);
    });

    testWidgets('shows category dropdown', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(noteId: null));
      await tester.pumpAndSettle();

      // Category dropdown should be present
      expect(find.byType(DropdownButton<int>), findsOneWidget);
    });

    testWidgets('back button calls onNoteCancelled when no changes',
        (WidgetTester tester) async {
      bool cancelledCalled = false;
      await tester.pumpWidget(buildTestApp(
        noteId: null,
        onNoteCancelled: () => cancelledCalled = true,
      ));
      await tester.pumpAndSettle();

      // Tap back arrow
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(cancelledCalled, isTrue);
    });
  });

  group('NoteEdit - Existing Note (not found)', () {
    testWidgets('shows error when note is not found in DB',
        (WidgetTester tester) async {
      // Mock returns null for getNote
      mockAdapter.noteToReturn = null;

      await tester.pumpWidget(buildTestApp(noteId: 999));
      await tester.pumpAndSettle();

      // Should show error text
      expect(find.text('Problem loading the note'), findsOneWidget);
    });

    testWidgets('shows "Edit note" title for existing note ID',
        (WidgetTester tester) async {
      mockAdapter.noteToReturn = null;

      await tester.pumpWidget(buildTestApp(noteId: 1));
      await tester.pumpAndSettle();

      // AppBar should show "Edit note"
      expect(find.text('Edit note'), findsOneWidget);
    });
  });

  group('NoteEdit - Delete button', () {
    testWidgets('shows delete button for existing note',
        (WidgetTester tester) async {
      mockAdapter.noteToReturn = null;

      await tester.pumpWidget(buildTestApp(noteId: 1));
      await tester.pumpAndSettle();

      // Delete button should be present for existing notes
      expect(find.byIcon(Icons.delete_rounded), findsOneWidget);
    });

    testWidgets('delete button calls onNoteDeleted callback',
        (WidgetTester tester) async {
      int? deletedId;
      mockAdapter.noteToReturn = null;

      await tester.pumpWidget(buildTestApp(
        noteId: 42,
        onNoteDeleted: (id) => deletedId = id,
      ));
      await tester.pumpAndSettle();

      // Tap delete
      await tester.tap(find.byIcon(Icons.delete_rounded));
      await tester.pumpAndSettle();

      expect(deletedId, equals(42));
    });
  });
}
