import 'package:andsafe/l10n/app_localizations.dart';
import 'package:andsafe/pages/signature_setup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestApp() {
    return MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: SignatureSetupPage(),
    );
  }

  group('SignatureSetupPage', () {
    testWidgets('renders page with title, instructions, and form fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // AppBar title
      expect(find.text('AndSafe'), findsOneWidget);

      // Setup instructions text
      expect(find.text('Setup encryption password'), findsOneWidget);

      // Two password fields (obscured TextFormFields)
      expect(find.byType(TextFormField), findsNWidgets(2));

      // Save button
      expect(find.widgetWithText(ElevatedButton, 'Save'), findsOneWidget);
    });

    testWidgets('shows password hint texts', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(
        find.text('Enter a password for encrypting your notes'),
        findsOneWidget,
      );
      expect(
        find.text('Enter the same password again for verification'),
        findsOneWidget,
      );
    });

    testWidgets('validation error when both passwords are empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Tap save without entering any password
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      // Should show validation error for empty password
      expect(find.text('Password cannot be empty'), findsOneWidget);
    });

    testWidgets('validation error when passwords do not match',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Enter different passwords
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'password1');
      await tester.enterText(fields.at(1), 'password2');

      // Tap save
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      // Should show mismatch error
      expect(find.text('The two passwords do not match'), findsOneWidget);
    });

    testWidgets('no validation error when passwords match',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Enter matching passwords
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'testPassword123');
      await tester.enterText(fields.at(1), 'testPassword123');

      // Tap save - validation should pass (but crypto/DB calls will fail)
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pump();

      // Should NOT show validation errors
      expect(find.text('Password cannot be empty'), findsNothing);
      expect(find.text('The two passwords do not match'), findsNothing);

      // The snackbar with "Generating encryption key..." should appear
      // (it's shown before the async work starts)
      expect(find.text('Generating encryption key...'), findsOneWidget);
    });

    testWidgets('validation error when only first password is entered',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Enter only the first password, leave second empty
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'testPassword123');

      // Tap save
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      // Second field should show mismatch error (empty != "testPassword123")
      expect(find.text('The two passwords do not match'), findsOneWidget);
    });

    testWidgets('validation error when only second password is entered',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Enter only the second password, leave first empty
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(1), 'testPassword123');

      // Tap save
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      // First field should show empty error
      expect(find.text('Password cannot be empty'), findsOneWidget);
      // Second field should show mismatch error (non-empty vs empty first field)
      expect(find.text('The two passwords do not match'), findsOneWidget);
    });

    testWidgets('toggles password visibility when eye icon is clicked',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Find the TextFormFields/TextFields
      final fieldsFinder = find.byType(TextField);
      expect(fieldsFinder, findsNWidgets(2));

      // Get the obscureText properties initially
      TextField field1 = tester.widget<TextField>(fieldsFinder.at(0));
      TextField field2 = tester.widget<TextField>(fieldsFinder.at(1));
      expect(field1.obscureText, isTrue);
      expect(field2.obscureText, isTrue);

      // Find the visibility icon buttons.
      final visibilityIcons = find.byIcon(Icons.visibility);
      expect(visibilityIcons, findsNWidgets(2));

      // Tap the first eye icon button
      await tester.tap(visibilityIcons.at(0));
      await tester.pumpAndSettle();

      // Verify first is visible, second is still obscured
      field1 = tester.widget<TextField>(fieldsFinder.at(0));
      field2 = tester.widget<TextField>(fieldsFinder.at(1));
      expect(field1.obscureText, isFalse);
      expect(field2.obscureText, isTrue);

      // Tap it again (now it has Icons.visibility_off)
      final visibilityOffIcons = find.byIcon(Icons.visibility_off);
      expect(visibilityOffIcons, findsOneWidget);
      await tester.tap(visibilityOffIcons);
      await tester.pumpAndSettle();

      // Verify it is obscured again
      field1 = tester.widget<TextField>(fieldsFinder.at(0));
      expect(field1.obscureText, isTrue);
    });
  });
}
