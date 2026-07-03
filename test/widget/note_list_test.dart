import 'dart:typed_data';

import 'package:andsafe/l10n/app_localizations.dart';
import 'package:andsafe/models/note.dart';
import 'package:andsafe/models/signature.dart';
import 'package:andsafe/pages/note_list.dart';
import 'package:andsafe/utils/services/database_service.dart' as db;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:andsafe/utils/services/preferences_service.dart';


import '../helpers/mock_database_adapter.dart';

Note _createMockNote(int id, String title, {int categoryId = 0}) {
  return Note(
    id,
    categoryId,
    title,
    'encrypted body',
    Uint8List(16),
    Uint8List(16),
    DateTime(2024, 1, id), // unique dates
  );
}

final _defaultPassword = Uint8List.fromList([1, 2, 3]);

void main() {
  late MockDatabaseAdapter mockAdapter;
  late db.DatabaseAdapter originalAdapter;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Prefs.resetForTesting();
    originalAdapter = db.adapter;
    mockAdapter = MockDatabaseAdapter();
    mockAdapter.overrideIsPasswordSet = true;
    db.adapter = mockAdapter;
  });

  tearDown(() {
    db.adapter = originalAdapter;
  });

  Widget buildTestApp({
    Uint8List? password,
    bool useNullPassword = false,
    Widget? drawer,
    ValueChanged<int>? onNoteSelected,
    VoidCallback? onNewNoteRequested,
    VoidCallback? onPasswordRequested,
    VoidCallback? onRefreshRequested,
    int refreshCounter = 0,
  }) {
    return MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: NoteList(
        password: useNullPassword ? null : (password ?? _defaultPassword),
        drawer: drawer,
        onNoteSelected: onNoteSelected,
        onNewNoteRequested: onNewNoteRequested,
        onPasswordRequested: onPasswordRequested,
        onRefreshRequested: onRefreshRequested,
        refreshCounter: refreshCounter,
      ),
    );
  }

  /// Pumps the widget tree until the FutureBuilder resolves and renders.
  /// The NoteList's FutureBuilder depends on SharedPreferences futures which
  /// need real async operations to complete. We use runAsync + pump in a
  /// loop to handle the preferences singleton caching across tests.
  Future<void> pumpUntilReady(WidgetTester tester) async {
    for (int i = 0; i < 5; i++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    }
  }

  group('NoteList - Empty State', () {
    testWidgets('renders with empty note list', (WidgetTester tester) async {
      mockAdapter.notesToReturn = [];
      await tester.pumpWidget(buildTestApp());
      await pumpUntilReady(tester);

      // AppBar title should be present
      expect(find.text('AndSafe'), findsOneWidget);

      // No note cards should be present
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('shows FAB even with empty list', (WidgetTester tester) async {
      mockAdapter.notesToReturn = [];
      await tester.pumpWidget(buildTestApp());
      await pumpUntilReady(tester);

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });

  group('NoteList - Note Rendering', () {
    testWidgets('renders note titles in list', (WidgetTester tester) async {
      mockAdapter.notesToReturn = [
        _createMockNote(1, 'First Note'),
        _createMockNote(2, 'Second Note'),
        _createMockNote(3, 'Third Note'),
      ];

      await tester.pumpWidget(buildTestApp());
      await pumpUntilReady(tester);

      expect(find.text('First Note'), findsOneWidget);
      expect(find.text('Second Note'), findsOneWidget);
      expect(find.text('Third Note'), findsOneWidget);
    });

    testWidgets('renders note cards', (WidgetTester tester) async {
      mockAdapter.notesToReturn = [
        _createMockNote(1, 'Note A'),
        _createMockNote(2, 'Note B'),
      ];

      await tester.pumpWidget(buildTestApp());
      await pumpUntilReady(tester);

      expect(find.byType(Card), findsNWidgets(2));
    });

    testWidgets('renders note dates as subtitles', (WidgetTester tester) async {
      mockAdapter.notesToReturn = [
        _createMockNote(1, 'Dated Note'),
      ];

      await tester.pumpWidget(buildTestApp());
      await pumpUntilReady(tester);

      // The date format is 'yyyy-MM-dd HH:mm:ss'
      // DateTime(2024, 1, 1) => '2024-01-01 00:00:00'
      expect(find.text('2024-01-01 00:00:00'), findsOneWidget);
    });
  });

  group('NoteList - Search', () {
    testWidgets('search field is present with hint text',
        (WidgetTester tester) async {
      mockAdapter.notesToReturn = [];
      await tester.pumpWidget(buildTestApp());
      await pumpUntilReady(tester);

      expect(find.text('Search title...'), findsOneWidget);
    });

    testWidgets('search field has clear button', (WidgetTester tester) async {
      mockAdapter.notesToReturn = [];
      await tester.pumpWidget(buildTestApp());
      await pumpUntilReady(tester);

      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);
    });

    testWidgets('search field has search icon', (WidgetTester tester) async {
      mockAdapter.notesToReturn = [];
      await tester.pumpWidget(buildTestApp());
      await pumpUntilReady(tester);

      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    });
  });

  group('NoteList - Sort Buttons', () {
    testWidgets('sort by alpha button is present', (WidgetTester tester) async {
      mockAdapter.notesToReturn = [];
      await tester.pumpWidget(buildTestApp());
      await pumpUntilReady(tester);

      expect(find.byIcon(Icons.sort_by_alpha_rounded), findsOneWidget);
    });

    testWidgets('sort by time button is present', (WidgetTester tester) async {
      mockAdapter.notesToReturn = [];
      await tester.pumpWidget(buildTestApp());
      await pumpUntilReady(tester);

      expect(find.byIcon(Icons.timer_rounded), findsOneWidget);
    });
  });

  group('NoteList - Callbacks', () {
    testWidgets('tapping note card calls onNoteSelected',
        (WidgetTester tester) async {
      int? selectedId;
      mockAdapter.notesToReturn = [
        _createMockNote(42, 'Tappable Note'),
      ];

      await tester.pumpWidget(buildTestApp(
        onNoteSelected: (id) => selectedId = id,
      ));
      await pumpUntilReady(tester);

      // Tap on the note
      await tester.tap(find.text('Tappable Note'));
      await tester.pump();

      expect(selectedId, equals(42));
    });

    testWidgets('tapping FAB calls onNewNoteRequested',
        (WidgetTester tester) async {
      bool newNoteCalled = false;
      mockAdapter.notesToReturn = [];

      await tester.pumpWidget(buildTestApp(
        onNewNoteRequested: () => newNoteCalled = true,
      ));
      await pumpUntilReady(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      expect(newNoteCalled, isTrue);
    });

    testWidgets('FAB calls onPasswordRequested when password is null',
        (WidgetTester tester) async {
      bool passwordRequested = false;
      mockAdapter.notesToReturn = [];

      await tester.pumpWidget(buildTestApp(
        useNullPassword: true,
        onPasswordRequested: () => passwordRequested = true,
      ));
      await pumpUntilReady(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      expect(passwordRequested, isTrue);
    });
  });

  group('NoteList - Drawer', () {
    testWidgets('renders with provided drawer widget',
        (WidgetTester tester) async {
      mockAdapter.notesToReturn = [];

      await tester.pumpWidget(buildTestApp(
        drawer: Drawer(
          child: ListView(
            children: [Text('Custom Drawer Content')],
          ),
        ),
      ));
      await pumpUntilReady(tester);

      // The drawer should be accessible via the Scaffold
      final scaffold =
          tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.drawer, isNotNull);
    });
  });
}
