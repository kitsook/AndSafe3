import 'dart:io';
import 'dart:typed_data';

import 'package:andsafe/config/routes/router.dart';
import 'package:andsafe/l10n/app_localizations.dart';
import 'package:andsafe/main.dart';
import 'package:andsafe/models/note.dart';
import 'package:andsafe/models/signature.dart';
import 'package:andsafe/pages/note_edit.dart';
import 'package:andsafe/pages/note_list.dart';
import 'package:andsafe/pages/signature_setup.dart';
import 'package:andsafe/utils/services/database_service.dart' as db;
import 'package:andsafe/utils/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_database_adapter.dart';

void main() {
  late MockDatabaseAdapter dbAdapter;
  late db.DatabaseAdapter originalAdapter;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Prefs.resetForTesting();
    // Pre-set biometric offered to true so biometric enrollment dialog does not prompt
    await Prefs.setBiometricOffered(true);

    originalAdapter = db.adapter;
    dbAdapter = MockDatabaseAdapter();
    db.adapter = dbAdapter;

    AndSafeRouter.setupRouter();
  });

  tearDown(() {
    db.adapter = originalAdapter;
  });

  /// Pumps the widget tree and ticks the fake clock to allow microtasks
  /// and navigator transitions to resolve. Avoids pumpAndSettle timeouts
  /// when active infinite spinning animations (like CircularProgressIndicator)
  /// are present in the tree.
  Future<void> pumpAndTransition(WidgetTester tester, {Duration stepDuration = const Duration(milliseconds: 100), int steps = 6}) async {
    for (int i = 0; i < steps; i++) {
      await tester.pump(stepDuration);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    }
  }

  testWidgets(
      'Full Integration Flow: launch -> signature setup -> home -> create note -> edit note -> delete note',
      (WidgetTester tester) async {
    // Configure tester window size to mobile portrait to avoid nested scaffolds and tablet split-screen layouts
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // 1. App Launch: should load signature setup screen since isPasswordSet() is initially false
    await tester.pumpWidget(MyApp(ThemeMode.system, false));
    await pumpAndTransition(tester);

    expect(find.byType(SignatureSetupPage), findsOneWidget);
    expect(find.text('Setup encryption password'), findsOneWidget);

    // Enter matching passwords
    final passwordFields = find.byType(TextFormField);
    await tester.enterText(passwordFields.at(0), 'superSecretPassword');
    await tester.enterText(passwordFields.at(1), 'superSecretPassword');
    await tester.pump();

    // Tap Save to set the signature/password
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pump();
    
    // We run async task to process signature setup scrypt generation (uses pointycastle fallback in tests)
    // and wait for loading overlay and transition to settle.
    await tester.runAsync(() async {
      for (int i = 0; i < 30; i++) {
        if (dbAdapter.signature != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    await pumpAndTransition(tester);

    // Verify signature was created in our mock DB
    expect(dbAdapter.signature, isNotNull);

    // 2. Home Page: note list should be shown and be empty initially
    expect(find.byType(NoteList), findsOneWidget);
    expect(find.byType(Card), findsNothing);

    // Let FAB scale animation complete in the Scaffold
    await tester.pump(const Duration(milliseconds: 500));

    // Tap Floating Action Button to create a new note
    await tester.tap(find.byType(FloatingActionButton));
    await pumpAndTransition(tester);

    // 3. Create Note screen
    expect(find.byType(NoteEdit), findsOneWidget);
    expect(find.text('Create note'), findsOneWidget);

    // Enter title & body
    final titleField = find.widgetWithText(TextFormField, 'Title of your note (not encrypted)');
    final bodyField = find.widgetWithText(TextFormField, 'Notes to be encrypted');
    await tester.enterText(titleField, 'Integration Note Title');
    await tester.enterText(bodyField, 'Integration secret body text');
    await tester.pump();

    // Tap back button (top left arrow) to trigger autosave and navigate back to list
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    
    // Run async since note creation invokes encrypt which runs async
    await tester.runAsync(() async {
      for (int i = 0; i < 30; i++) {
        if (dbAdapter.notes.isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    await pumpAndTransition(tester);

    // 4. Note List should now contain our new note card
    expect(find.byType(NoteList), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
    expect(find.text('Integration Note Title'), findsOneWidget);

    // 5. Edit Note: tap the note card to view/edit it
    await tester.tap(find.text('Integration Note Title'));
    await pumpAndTransition(tester);
    
    // Wait until decryption finishes and text is populated
    for (int i = 0; i < 30; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      if (find.text('Integration secret body text').evaluate().isNotEmpty) break;
    }

    // Verify it is decrypted correctly in the edit fields
    expect(find.text('Integration Note Title'), findsWidgets); // Both title & field
    expect(find.text('Integration secret body text'), findsOneWidget);

    // Modify the title & body
    await tester.enterText(titleField, 'Updated Note Title');
    await tester.enterText(bodyField, 'Updated body text');
    await tester.pump();

    // Tap back button to trigger autosave
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    
    // Wait until update and save finishes
    await tester.runAsync(() async {
      for (int i = 0; i < 30; i++) {
        if (dbAdapter.notes.isNotEmpty && dbAdapter.notes.first.title == 'Updated Note Title') break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    await pumpAndTransition(tester);

    // Verify update reflected in Note List
    expect(find.text('Updated Note Title'), findsOneWidget);
    expect(find.text('Integration Note Title'), findsNothing);

    // 6. Delete Note: tap to open again
    await tester.tap(find.text('Updated Note Title'));
    await pumpAndTransition(tester);
    
    // Wait until decryption finishes and text is populated
    for (int i = 0; i < 30; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      if (find.text('Updated body text').evaluate().isNotEmpty) break;
    }

    // Tap delete button in AppBar
    await tester.tap(find.byIcon(Icons.delete_rounded));
    await pumpAndTransition(tester);

    // Note list should be empty again
    expect(find.byType(Card), findsNothing);
    expect(find.text('Updated Note Title'), findsNothing);

    // Check that undo SnackBar message is shown
    expect(find.text('Going to delete note...'), findsOneWidget);
  });
}
