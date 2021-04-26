
import 'package:andsafe/utils/ThemeChanger.dart';
import 'package:andsafe/utils/logger.dart';
import 'package:andsafe/utils/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class ChangeSettingsPage extends StatefulWidget {

  @override
  State<StatefulWidget> createState() {
    return _ChangeSettingsPageState();
  }
}

class _ChangeSettingsPageState extends State {
  final _formKey = GlobalKey<FormState>();
  String _theme = PREF_THEME_SYSTEM;
  bool _swipeToDelete = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  void _loadPrefs() {
    Prefs.getSelectedTheme()
      .then((value) => this._theme = value)
      .then((_) => Prefs.getSwipeToDelete())
      .then((value) => this._swipeToDelete = value)
      .then((_) {
        setState(() {
        });
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.changeSettingsTitle),
      ),
      body: Container(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVerticalSpacing(),
              _buildThemeSelection(),
              _buildVerticalSpacing(),
              Divider(height: 2),
              _buildVerticalSpacing(),
              _buildSwipeDeleteToogle(),
              ],
            ),
          ),
        ),
      )
    );
  }

  Widget _buildVerticalSpacing() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
    );
  }

  Widget _buildThemeSelection() {
    return Column(
      children: [
        ListTile(
          title: Text(AppLocalizations.of(context)!.themeSetting),
        ),
        new Container(
          height: 8.0,
        ),
        ToggleButtons(
          children: [
            Icon(Icons.settings_rounded),
            Icon(Icons.wb_sunny_rounded),
            Icon(Icons.nightlight_round),
          ],
          onPressed: (index) {
            switch(index) {
              case 0: {
                Prefs.setSelectedTheme(PREF_THEME_SYSTEM).then((_) {
                  this._theme = PREF_THEME_SYSTEM;
                });
                Provider.of<ThemeChanger>(context, listen: false).themeMode = ThemeMode.system;
              }
              break;

              case 1: {
                Prefs.setSelectedTheme(PREF_THEME_LIGHT).then((_) {
                  this._theme = PREF_THEME_LIGHT;
                });
                Provider.of<ThemeChanger>(context, listen: false).themeMode = ThemeMode.light;
              }
              break;

              case 2: {
                Prefs.setSelectedTheme(PREF_THEME_DARK).then((_) {
                  this._theme = PREF_THEME_DARK;
                });
                Provider.of<ThemeChanger>(context, listen: false).themeMode = ThemeMode.dark;
              }
              break;

              default: {
                Prefs.setSelectedTheme(PREF_THEME_SYSTEM).then((_) {
                  this._theme = PREF_THEME_SYSTEM;
                });
                Provider.of<ThemeChanger>(context, listen: false).themeMode = ThemeMode.system;
              }
            }
          },
          isSelected: [
            this._theme == PREF_THEME_SYSTEM,
            this._theme == PREF_THEME_LIGHT,
            this._theme == PREF_THEME_DARK,
          ],
        ),
      ],
    );
  }

  Widget _buildSwipeDeleteToogle() {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.swipeToDeleteSetting),
      trailing: Switch(
        value: _swipeToDelete,
        onChanged: (value) {
          setState(() {
            Prefs.setSwipeToDelete(value).then((_) {
              this._swipeToDelete = value;
            });
          });
        }
      ),
    );
  }
}