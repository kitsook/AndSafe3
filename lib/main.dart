import 'package:andsafe/config/routes/router.dart';
import 'package:andsafe/utils/ThemeChanger.dart';
import 'package:andsafe/utils/logger.dart';
import 'package:andsafe/utils/services/preferences_service.dart';
import 'package:flag_secure/flag_secure.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';


void main() async {
  setupLogger();
  WidgetsFlutterBinding.ensureInitialized();
  String theme = await Prefs.getSelectedTheme();
  ThemeMode themeMode =
    theme == PREF_THEME_LIGHT? ThemeMode.light :
      theme == PREF_THEME_DARK? ThemeMode.dark : ThemeMode.system;
  AndSafeRouter.setupRouter();
  runApp(MyApp(themeMode));
}

class MyApp extends StatelessWidget {
  final ThemeMode themeMode;

  MyApp(this.themeMode);

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

    return ChangeNotifierProvider(
      create: (_) => ThemeChanger(themeMode),
      child: Consumer<ThemeChanger>(
        builder: (_, themeChanger, __) {
          return MaterialApp(
            // debugShowCheckedModeBanner: false,
            title: 'AndSafe',
            theme: ThemeData(
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
            ),
            themeMode: themeChanger.themeMode,
            initialRoute: 'signatureSetup',
            onGenerateRoute: AndSafeRouter.router.generator,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
          );
        }
      ),
    );
  }
}

