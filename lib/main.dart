import 'package:andsafe/config/routes/router.dart';
import 'package:andsafe/l10n/app_localizations.dart';
import 'package:andsafe/utils/ThemeChanger.dart';
import 'package:andsafe/utils/logger.dart';
import 'package:andsafe/utils/services/preferences_service.dart';
import 'package:andsafe/utils/services/database_service.dart' as db;
import 'package:flag_secure/flag_secure.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

void main() async {
  setupLogger();
  WidgetsFlutterBinding.ensureInitialized();
  AndSafeRouter.setupRouter();

  String theme = await Prefs.getSelectedTheme();
  ThemeMode themeMode = theme == PREF_THEME_LIGHT
      ? ThemeMode.light
      : theme == PREF_THEME_DARK
          ? ThemeMode.dark
          : ThemeMode.system;

  final dbHelper = db.DatabaseHelper();
  final database = await dbHelper.getDatabase();
  final noteService = db.NoteService(database);
  final signatureService = db.SignatureService(database);
  bool isPasswordSet = await signatureService.isPasswordSet();

  runApp(MyApp(themeMode, isPasswordSet, noteService, signatureService));
}

class MyApp extends StatelessWidget {
  final ThemeMode themeMode;
  final bool isPasswordSet;
  final db.NoteService noteService;
  final db.SignatureService signatureService;

  MyApp(this.themeMode, this.isPasswordSet, this.noteService, this.signatureService);

  Future<void> _setFlagSecure() async {
    try {
      await FlagSecure.set();
    } on PlatformException catch (e) {
      log.severe(e.toString());
    }
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    _setFlagSecure();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeChanger(themeMode)),
        Provider<db.NoteService>.value(value: noteService),
        Provider<db.SignatureService>.value(value: signatureService),
      ],
      child: Consumer<ThemeChanger>(builder: (_, themeChanger, __) {
        return MaterialApp(
          // debugShowCheckedModeBanner: false,
          title: 'AndSafe',
          theme: ThemeData(
            brightness: Brightness.light,
            colorSchemeSeed: Colors.teal,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorSchemeSeed: Colors.teal,
          ),
          themeMode: themeChanger.themeMode,
          initialRoute: isPasswordSet ? 'home' : 'signatureSetup',
          onGenerateRoute: AndSafeRouter.router.generator,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
        );
      }),
    );
  }
}
