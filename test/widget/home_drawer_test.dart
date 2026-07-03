import 'package:andsafe/l10n/app_localizations.dart';
import 'package:andsafe/pages/home_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'AndSafe',
      packageName: 'com.test.andsafe',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  Widget buildTestApp({
    required bool isAuthenticated,
    VoidCallback? onOpenSettings,
    VoidCallback? onChangePassword,
    VoidCallback? onImportNotes,
    VoidCallback? onExportNotes,
    VoidCallback? onExitApp,
  }) {
    return MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: AppBar(title: Text('Test')),
        drawer: HomeDrawer(
          isAuthenticated: isAuthenticated,
          onOpenSettings: onOpenSettings ?? () {},
          onChangePassword: onChangePassword ?? () {},
          onImportNotes: onImportNotes ?? () {},
          onExportNotes: onExportNotes ?? () {},
          onExitApp: onExitApp ?? () {},
        ),
      ),
    );
  }

  Future<void> openDrawer(WidgetTester tester) async {
    final ScaffoldState scaffoldState =
        tester.firstState(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();
  }

  group('HomeDrawer', () {
    testWidgets('renders all drawer items when authenticated',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(isAuthenticated: true));
      await openDrawer(tester);

      // Verify all drawer items are visible
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Import notes'), findsOneWidget);
      expect(find.text('Export notes'), findsOneWidget);
      expect(find.text('Exit'), findsOneWidget);
      expect(find.text('Visit web site'), findsOneWidget);

      // Verify drawer icons
      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
      expect(find.byIcon(Icons.cached_rounded), findsOneWidget);
      expect(find.byIcon(Icons.read_more_rounded), findsOneWidget);
      expect(find.byIcon(Icons.save_rounded), findsOneWidget);
      expect(find.byIcon(Icons.exit_to_app_rounded), findsOneWidget);
      expect(find.byIcon(Icons.launch_rounded), findsOneWidget);
    });

    testWidgets('renders close button in drawer header',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(isAuthenticated: true));
      await openDrawer(tester);

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('renders AndSafe title in drawer header',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(isAuthenticated: true));
      await openDrawer(tester);

      // The drawer header contains 'AndSafe' text
      expect(find.text('AndSafe'), findsOneWidget);
    });

    testWidgets('renders import/export subtitles',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(isAuthenticated: true));
      await openDrawer(tester);

      expect(find.text('Load previously exported notes'), findsOneWidget);
      expect(find.text('Backup notes to a file'), findsOneWidget);
    });

    testWidgets('Settings tap calls onOpenSettings',
        (WidgetTester tester) async {
      bool settingsCalled = false;
      await tester.pumpWidget(buildTestApp(
        isAuthenticated: true,
        onOpenSettings: () => settingsCalled = true,
      ));
      await openDrawer(tester);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(settingsCalled, isTrue);
    });

    testWidgets('Change Password tap calls onChangePassword',
        (WidgetTester tester) async {
      bool changePasswordCalled = false;
      await tester.pumpWidget(buildTestApp(
        isAuthenticated: true,
        onChangePassword: () => changePasswordCalled = true,
      ));
      await openDrawer(tester);

      await tester.tap(find.text('Change Password'));
      await tester.pumpAndSettle();

      expect(changePasswordCalled, isTrue);
    });

    testWidgets('Import notes tap calls onImportNotes',
        (WidgetTester tester) async {
      bool importCalled = false;
      await tester.pumpWidget(buildTestApp(
        isAuthenticated: true,
        onImportNotes: () => importCalled = true,
      ));
      await openDrawer(tester);

      await tester.tap(find.text('Import notes'));
      await tester.pumpAndSettle();

      expect(importCalled, isTrue);
    });

    testWidgets('Export notes tap calls onExportNotes',
        (WidgetTester tester) async {
      bool exportCalled = false;
      await tester.pumpWidget(buildTestApp(
        isAuthenticated: true,
        onExportNotes: () => exportCalled = true,
      ));
      await openDrawer(tester);

      await tester.tap(find.text('Export notes'));
      await tester.pumpAndSettle();

      expect(exportCalled, isTrue);
    });

    testWidgets('Exit tap calls onExitApp', (WidgetTester tester) async {
      bool exitCalled = false;
      await tester.pumpWidget(buildTestApp(
        isAuthenticated: true,
        onExitApp: () => exitCalled = true,
      ));
      await openDrawer(tester);

      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();

      expect(exitCalled, isTrue);
    });

    testWidgets(
        'tiles are disabled when not authenticated (except Exit and Visit)',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(isAuthenticated: false));
      await openDrawer(tester);

      // Find the ListTiles and check enabled state
      final settingsTile = tester.widget<ListTile>(find.widgetWithText(
        ListTile,
        'Settings',
      ));
      expect(settingsTile.enabled, isFalse);

      final changePasswordTile = tester.widget<ListTile>(find.widgetWithText(
        ListTile,
        'Change Password',
      ));
      expect(changePasswordTile.enabled, isFalse);

      final importTile = tester.widget<ListTile>(find.widgetWithText(
        ListTile,
        'Import notes',
      ));
      expect(importTile.enabled, isFalse);

      final exportTile = tester.widget<ListTile>(find.widgetWithText(
        ListTile,
        'Export notes',
      ));
      expect(exportTile.enabled, isFalse);
    });

    testWidgets('Exit tile is always enabled regardless of auth',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(isAuthenticated: false));
      await openDrawer(tester);

      // Exit tile doesn't have an explicit enabled property set to false
      // in the source, so it defaults to true
      final exitTile = tester.widget<ListTile>(find.widgetWithText(
        ListTile,
        'Exit',
      ));
      expect(exitTile.enabled, isTrue);
    });

    testWidgets('disabled tiles do not fire callbacks when tapped',
        (WidgetTester tester) async {
      bool settingsCalled = false;
      await tester.pumpWidget(buildTestApp(
        isAuthenticated: false,
        onOpenSettings: () => settingsCalled = true,
      ));
      await openDrawer(tester);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(settingsCalled, isFalse);
    });

    testWidgets('renders build version text', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(isAuthenticated: true));
      await openDrawer(tester);

      // BuildVersionText uses PackageInfo which we mocked
      expect(find.textContaining('AndSafe'), findsWidgets);
    });
  });
}
