import 'package:shared_preferences/shared_preferences.dart';

const prefSortKeyTitle = 'title';
const prefSortKeyLastUpdate = 'last_update';
const prefThemeSystem = 'system';
const prefThemeLight = 'light';
const prefThemeDark = 'dark';

const String _prefKeySort = 'SelectedSorting';
const String _prefKeySortAscending = 'SelectedSortAscending';
const String _prefKeyTheme = 'SelectedTheme';
const String _prefKeySwipeToDelete = 'SwipeToDelete';
const String _prefKeyBiometricEnabled = 'BiometricEnabled';
const String _prefKeyBiometricOffered = 'BiometricOffered';

_PreferenceService _prefService = _PreferenceService();

class Prefs {
  /// Resets the preference service singleton. Used to clear cached `Future<SharedPreferences>`
  /// across test boundaries when mocks are re-registered.
  static void resetForTesting() {
    _prefService = _PreferenceService();
  }

  static Future<String> getSortBy() async {
    String sortBy = await _prefService.getString(_prefKeySort);
    if (sortBy == prefSortKeyTitle || sortBy == prefSortKeyLastUpdate) {
      return sortBy;
    } else {
      return prefSortKeyTitle;
    }
  }

  static Future<void> setSortBy(String sortBy) async {
    if (sortBy != prefSortKeyTitle && sortBy != prefSortKeyLastUpdate) {
      await _prefService.setString(_prefKeySort, prefSortKeyTitle);
    } else {
      await _prefService.setString(_prefKeySort, sortBy);
    }
  }

  static Future<bool> isSortAscending() async {
    return await _prefService.getBool(_prefKeySortAscending);
  }

  static Future<void> setSortAscending(bool sortAscending) async {
    await _prefService.setBool(_prefKeySortAscending, sortAscending);
  }

  static Future<String> getSelectedTheme() async {
    String theTheme = await _prefService.getString(_prefKeyTheme);
    if (theTheme == prefThemeSystem ||
        theTheme == prefThemeLight ||
        theTheme == prefThemeDark) {
      return theTheme;
    } else {
      return prefThemeSystem;
    }
  }

  static Future<void> setSelectedTheme(String theTheme) async {
    if (theTheme == prefThemeSystem ||
        theTheme == prefThemeLight ||
        theTheme == prefThemeDark) {
      await _prefService.setString(_prefKeyTheme, theTheme);
    } else {
      await _prefService.setString(_prefKeyTheme, prefThemeSystem);
    }
  }

  static Future<bool> getSwipeToDelete() async {
    return await _prefService.getBool(_prefKeySwipeToDelete);
  }

  static Future<void> setSwipeToDelete(bool swipeToDelete) async {
    await _prefService.setBool(_prefKeySwipeToDelete, swipeToDelete);
  }

  static Future<bool> getBiometricEnabled() async {
    return await _prefService.getBoolDefault(_prefKeyBiometricEnabled, false);
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    await _prefService.setBool(_prefKeyBiometricEnabled, enabled);
  }

  static Future<bool> getBiometricOffered() async {
    return await _prefService.getBoolDefault(_prefKeyBiometricOffered, false);
  }

  static Future<void> setBiometricOffered(bool offered) async {
    await _prefService.setBool(_prefKeyBiometricOffered, offered);
  }
}

class _PreferenceService {
  Future<SharedPreferences>? _prefs;

  _PreferenceService() {
    _prefs = _init();
  }

  Future<SharedPreferences> _init() async {
    return SharedPreferences.getInstance();
  }

  Future<String> getString(String key) async {
    try {
      SharedPreferences prefs = await _prefs!;
      return prefs.getString(key) ?? "";
    } catch (e) {
      return "";
    }
  }

  Future<void> setString(String key, String value) async {
    try {
      SharedPreferences prefs = await _prefs!;
      prefs.setString(key, value);
    } catch (e) {
      // ignore
    }
  }

  Future<int> getInt(String key) async {
    try {
      SharedPreferences prefs = await _prefs!;
      return prefs.getInt(key) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> setInt(String key, int value) async {
    try {
      SharedPreferences prefs = await _prefs!;
      prefs.setInt(key, value);
    } catch (e) {
      // ignore
    }
  }

  Future<bool> getBool(String key) async {
    try {
      SharedPreferences prefs = await _prefs!;
      return prefs.getBool(key) ?? true;
    } catch (e) {
      return true;
    }
  }

  Future<bool> getBoolDefault(String key, bool defaultValue) async {
    try {
      SharedPreferences prefs = await _prefs!;
      return prefs.getBool(key) ?? defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  Future<void> setBool(String key, bool value) async {
    try {
      SharedPreferences prefs = await _prefs!;
      prefs.setBool(key, value);
    } catch (e) {
      // ignore
    }
  }
}
