import 'dart:typed_data';

import 'package:andsafe/l10n/app_localizations.dart';
import 'package:andsafe/utils/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestApp({
    required Widget child,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  group('PasswordInputDialog', () {
    testWidgets('renders password field obscured by default', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const PasswordInputDialog(biometricEnabled: false),
        ),
      );
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.obscureText, isTrue);
    });

    testWidgets('toggles obscureText when visibility icon is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const PasswordInputDialog(biometricEnabled: false),
        ),
      );
      await tester.pumpAndSettle();

      // Tap visibility toggle icon
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isFalse);

      // Tap again to obscure
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();

      final textFieldObscured = tester.widget<TextField>(find.byType(TextField));
      expect(textFieldObscured.obscureText, isTrue);
    });

    testWidgets('submitting password returns PasswordInputDialogResult.password and safely disposes',
        (WidgetTester tester) async {
      PasswordInputDialogResult? result;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showDialog<PasswordInputDialogResult>(
                    context: context,
                    builder: (_) => const PasswordInputDialog(biometricEnabled: false),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Enter password
      await tester.enterText(find.byType(TextField), 'secret123');

      // Tap submit arrow
      await tester.tap(find.byIcon(Icons.arrow_right_alt_rounded));

      // Pump through animation frames
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(result, isNotNull);
      expect(result!.isBiometric, isFalse);
      expect(result!.password, 'secret123');
    });

    testWidgets('biometric button returns PasswordInputDialogResult.biometric when tapped',
        (WidgetTester tester) async {
      PasswordInputDialogResult? result;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showDialog<PasswordInputDialogResult>(
                    context: context,
                    builder: (_) => const PasswordInputDialog(biometricEnabled: true),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap biometric button
      await tester.tap(find.byType(FilledButton));

      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(result, isNotNull);
      expect(result!.isBiometric, isTrue);
      expect(result!.password, isNull);
    });
  });

  group('AuthService - Session-Based Purging', () {
    testWidgets('lockSession purges password and triggers wipe callback', (WidgetTester tester) async {
      Uint8List? activePassword = Uint8List.fromList([1, 2, 3, 4]);
      bool wipeCallbackCalled = false;

      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (context) {
              final authService = AuthService(
                context: context,
                setState: (fn) => fn(),
                setIsBusy: (_) {},
                setPassword: (p) => activePassword = p,
                refreshCounter: () => 0,
                setRefreshCounter: (_) {},
              );

              return ElevatedButton(
                onPressed: () {
                  authService.lockSession(onWipeComplete: () {
                    wipeCallbackCalled = true;
                  });
                },
                child: const Text('Lock'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(activePassword, isNotNull);
      await tester.tap(find.text('Lock'));
      await tester.pumpAndSettle();

      expect(activePassword, isNull);
      expect(wipeCallbackCalled, isTrue);
    });
  });
}
