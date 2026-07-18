import 'package:andsafe/l10n/app_localizations.dart';
import 'package:andsafe/pages/change_password.dart';
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
      home: ChangePasswordPage(),
    );
  }

  group('ChangePasswordPage', () {
    testWidgets('renders all password fields and they are obscured by default',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Should find three text fields
      final fieldsFinder = find.byType(TextField);
      expect(fieldsFinder, findsNWidgets(3));

      // All should be obscured initially
      for (int i = 0; i < 3; i++) {
        final field = tester.widget<TextField>(fieldsFinder.at(i));
        expect(field.obscureText, isTrue);
      }
    });

    testWidgets('toggles visibility for each password field independently',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final fieldsFinder = find.byType(TextField);

      // Helper finder to get the IconButton of a specific TextField
      Finder getIconButtonForField(int index) {
        return find.descendant(
          of: fieldsFinder.at(index),
          matching: find.byType(IconButton),
        );
      }

      // Verify there are three visibility toggle buttons
      expect(getIconButtonForField(0), findsOneWidget);
      expect(getIconButtonForField(1), findsOneWidget);
      expect(getIconButtonForField(2), findsOneWidget);

      // Tap the first visibility button (Current Password)
      await tester.tap(getIconButtonForField(0));
      await tester.pumpAndSettle();

      // First should be visible, others should be obscured
      expect(tester.widget<TextField>(fieldsFinder.at(0)).obscureText, isFalse);
      expect(tester.widget<TextField>(fieldsFinder.at(1)).obscureText, isTrue);
      expect(tester.widget<TextField>(fieldsFinder.at(2)).obscureText, isTrue);

      // Tap the second visibility button (New Password)
      await tester.tap(getIconButtonForField(1));
      await tester.pumpAndSettle();

      // First and second should be visible, third should be obscured
      expect(tester.widget<TextField>(fieldsFinder.at(0)).obscureText, isFalse);
      expect(tester.widget<TextField>(fieldsFinder.at(1)).obscureText, isFalse);
      expect(tester.widget<TextField>(fieldsFinder.at(2)).obscureText, isTrue);

      // Tap the first visibility off button (to hide the Current Password again)
      await tester.tap(getIconButtonForField(0));
      await tester.pumpAndSettle();

      // First should be obscured, second is visible, third is obscured
      expect(tester.widget<TextField>(fieldsFinder.at(0)).obscureText, isTrue);
      expect(tester.widget<TextField>(fieldsFinder.at(1)).obscureText, isFalse);
      expect(tester.widget<TextField>(fieldsFinder.at(2)).obscureText, isTrue);
    });
  });
}
