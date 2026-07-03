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
  });
}
