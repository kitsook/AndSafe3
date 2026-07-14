import 'package:andsafe/l10n/app_localizations.dart';
import 'package:andsafe/pages/settings.dart';
import 'package:andsafe/utils/theme_changer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestApp() {
    return ChangeNotifierProvider(
      create: (_) => ThemeChanger(ThemeMode.system),
      child: MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangeSettingsPage(),
      ),
    );
  }

  group('ChangeSettingsPage', () {
    testWidgets('renders page with Settings title',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      // Use pump with duration to let initial async work settle,
      // without waiting for biometric service (which may throw
      // MissingPluginException in test environment).
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('renders theme section with icon and text',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 500));

      // Theme label
      expect(find.text('Theme'), findsOneWidget);
      expect(find.byIcon(Icons.palette_rounded), findsOneWidget);
    });

    testWidgets('renders three theme toggle buttons',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 500));

      // ToggleButtons with 3 icons: system, light, dark
      expect(find.byType(ToggleButtons), findsOneWidget);
      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
      expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);
      expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
    });

    testWidgets('renders swipe to delete toggle',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Swipe to delete note'), findsOneWidget);
      expect(find.byIcon(Icons.swipe_rounded), findsOneWidget);

      // A Switch widget should be present for swipe to delete
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('renders biometric unlock toggle',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Biometric unlock'), findsOneWidget);
      expect(find.byIcon(Icons.fingerprint), findsOneWidget);
    });

    testWidgets('tapping light theme toggle updates provider',
        (WidgetTester tester) async {
      late ThemeChanger themeChanger;
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) {
            themeChanger = ThemeChanger(ThemeMode.system);
            return themeChanger;
          },
          child: MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: ChangeSettingsPage(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Tap the light theme button (sun icon, index 1)
      await tester.tap(find.byIcon(Icons.wb_sunny_rounded));
      await tester.pump(const Duration(milliseconds: 500));

      expect(themeChanger.themeMode, equals(ThemeMode.light));
    });

    testWidgets('tapping dark theme toggle updates provider',
        (WidgetTester tester) async {
      late ThemeChanger themeChanger;
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) {
            themeChanger = ThemeChanger(ThemeMode.system);
            return themeChanger;
          },
          child: MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: ChangeSettingsPage(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Tap the dark theme button (moon icon, index 2)
      await tester.tap(find.byIcon(Icons.nightlight_round));
      await tester.pump(const Duration(milliseconds: 500));

      expect(themeChanger.themeMode, equals(ThemeMode.dark));
    });

    testWidgets('tapping system theme toggle updates provider',
        (WidgetTester tester) async {
      late ThemeChanger themeChanger;
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) {
            // Start with light theme so toggling to system is a change
            themeChanger = ThemeChanger(ThemeMode.light);
            return themeChanger;
          },
          child: MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: ChangeSettingsPage(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Tap the system theme button (settings icon, index 0)
      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pump(const Duration(milliseconds: 500));

      expect(themeChanger.themeMode, equals(ThemeMode.system));
    });

    testWidgets('has dividers between sections', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 500));

      // Two dividers separate the three sections
      expect(find.byType(Divider), findsNWidgets(2));
    });
  });
}
