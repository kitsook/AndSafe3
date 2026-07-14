import 'dart:typed_data';

import 'package:andsafe/l10n/app_localizations.dart';
import 'package:andsafe/utils/theme_changer.dart';
import 'package:andsafe/utils/notification.dart';
import 'package:andsafe/utils/services/biometric_service.dart';
import 'package:andsafe/utils/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChangeSettingsPage extends StatefulWidget {
  const ChangeSettingsPage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _ChangeSettingsPageState();
  }
}

class _ChangeSettingsPageState extends State {
  final _formKey = GlobalKey<FormState>();
  String _theme = prefThemeSystem;
  bool _swipeToDelete = true;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  final BiometricService _biometricService = BiometricService();
  Uint8List? _password;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final arguments = ModalRoute.of(context)?.settings.arguments as Map?;
      if (arguments != null && arguments.containsKey('password')) {
        _password = arguments['password'];
      }
    });
  }

  void _loadPrefs() {
    Prefs.getSelectedTheme()
        .then((value) => _theme = value)
        .then((_) => Prefs.getSwipeToDelete())
        .then((value) => _swipeToDelete = value)
        .then((_) => Prefs.getBiometricEnabled())
        .then((value) => _biometricEnabled = value)
        .then((_) => _biometricService.isBiometricAvailable())
        .then((value) => _biometricAvailable = value)
        .then((_) {
      setState(() {});
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
                  _buildVerticalSpacing(),
                  Divider(height: 2),
                  _buildVerticalSpacing(),
                  _buildBiometricToggle(),
                ],
              ),
            ),
          ),
        ));
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
          leading: Icon(Icons.palette_rounded),
          title: Text(AppLocalizations.of(context)!.themeSetting),
        ),
        Container(
          height: 8.0,
        ),
        ToggleButtons(
          onPressed: (index) {
            switch (index) {
              case 0:
                {
                  Prefs.setSelectedTheme(prefThemeSystem).then((_) {
                    _theme = prefThemeSystem;
                  });
                  Provider.of<ThemeChanger>(context, listen: false).themeMode =
                      ThemeMode.system;
                }
                break;

              case 1:
                {
                  Prefs.setSelectedTheme(prefThemeLight).then((_) {
                    _theme = prefThemeLight;
                  });
                  Provider.of<ThemeChanger>(context, listen: false).themeMode =
                      ThemeMode.light;
                }
                break;

              case 2:
                {
                  Prefs.setSelectedTheme(prefThemeDark).then((_) {
                    _theme = prefThemeDark;
                  });
                  Provider.of<ThemeChanger>(context, listen: false).themeMode =
                      ThemeMode.dark;
                }
                break;

              default:
                {
                  Prefs.setSelectedTheme(prefThemeSystem).then((_) {
                    _theme = prefThemeSystem;
                  });
                  Provider.of<ThemeChanger>(context, listen: false).themeMode =
                      ThemeMode.system;
                }
            }
          },
          isSelected: [
            _theme == prefThemeSystem,
            _theme == prefThemeLight,
            _theme == prefThemeDark,
          ],
          children: [
            Icon(Icons.settings_rounded),
            Icon(Icons.wb_sunny_rounded),
            Icon(Icons.nightlight_round),
          ],
        ),
      ],
    );
  }

  Widget _buildSwipeDeleteToogle() {
    return ListTile(
      leading: Icon(Icons.swipe_rounded),
      title: Text(AppLocalizations.of(context)!.swipeToDeleteSetting),
      trailing: Switch(
          value: _swipeToDelete,
          onChanged: (value) {
            setState(() {
              Prefs.setSwipeToDelete(value).then((_) {
                _swipeToDelete = value;
              });
            });
          }),
    );
  }

  Widget _buildBiometricToggle() {
    return ListTile(
      leading: Icon(Icons.fingerprint),
      title: Text(AppLocalizations.of(context)!.biometricUnlockSetting),
      trailing: Switch(
        value: _biometricEnabled,
        onChanged: _biometricAvailable && _password != null
            ? (value) async {
                if (value) {
                  // Store the password in biometric-protected secure storage
                  final bool stored =
                      await _biometricService.storePassword(_password!);
                  if (mounted) {
                    displaySnackBarMsg(
                      context: context,
                      msg: stored
                          ? AppLocalizations.of(context)!.biometricEnabled
                          : AppLocalizations.of(context)!.biometricFailed,
                    );
                  }
                  if (stored) {
                    setState(() {
                      _biometricEnabled = true;
                    });
                  }
                } else {
                  // Disabling: clear stored password
                  await _biometricService.clearStoredPassword();
                  if (mounted) {
                    displaySnackBarMsg(
                      context: context,
                      msg: AppLocalizations.of(context)!.biometricDisabled,
                    );
                  }
                  setState(() {
                    _biometricEnabled = false;
                  });
                }
              }
            : null,
      ),
    );
  }
}
