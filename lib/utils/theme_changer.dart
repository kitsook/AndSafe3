import 'package:flutter/material.dart';

class ThemeChanger extends ChangeNotifier {
  ThemeChanger(ThemeMode themeMode) : _themeMode = themeMode;

  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  set themeMode(ThemeMode value) {
    _themeMode = value;
    notifyListeners();
  }
}
