import 'package:shared_preferences/shared_preferences.dart';

const PREF_SORT_KEY_TITLE = 'title';
const PREF_SORT_KEY_LAST_UPDATE = 'last_update';
const PREF_THEME_SYSTEM = 'system';
const PREF_THEME_LIGHT = 'light';
const PREF_THEME_DARK = 'dark';

const String _PREF_KEY_SORT = 'SelectedSorting';
const String _PREF_KEY_SORT_ASCENDING = 'SelectedSortAscending';
const String _PREF_KEY_THEME = 'SelectedTheme';
const String _PREF_KEY_SWIPE_TO_DELETE = 'SwipeToDelete';


_PreferenceService _prefService = _PreferenceService();

class Prefs {
  static Future<String> getSortBy() async {
    String sortBy = await _prefService.getString(_PREF_KEY_SORT);
    if (sortBy == PREF_SORT_KEY_TITLE || sortBy == PREF_SORT_KEY_LAST_UPDATE) {
      return sortBy;
    } else {
      return PREF_SORT_KEY_TITLE;
    }
  }

  static Future<void> setSortBy(String sortBy) async {
    if (sortBy != PREF_SORT_KEY_TITLE && sortBy != PREF_SORT_KEY_LAST_UPDATE) {
      await _prefService.setString(_PREF_KEY_SORT, PREF_SORT_KEY_TITLE);
    } else {
      await _prefService.setString(_PREF_KEY_SORT, sortBy);
    }
  }

  static Future<bool> isSortAscending() async {
    return await _prefService.getBool(_PREF_KEY_SORT_ASCENDING);
  }

  static Future<void> setSortAscending(bool sortAscending) async {
    await _prefService.setBool(_PREF_KEY_SORT_ASCENDING, sortAscending);
  }

  static Future<String> getSelectedTheme() async {
    String theTheme = await _prefService.getString(_PREF_KEY_THEME);
    if (theTheme == PREF_THEME_SYSTEM || theTheme == PREF_THEME_LIGHT || theTheme == PREF_THEME_DARK) {
      return theTheme;
    } else {
      return PREF_THEME_SYSTEM;
    }
  }

  static Future<void> setSelectedTheme(String theTheme) async {
    if (theTheme == PREF_THEME_SYSTEM || theTheme == PREF_THEME_LIGHT || theTheme == PREF_THEME_DARK) {
      await _prefService.setString(_PREF_KEY_THEME, theTheme);
    } else {
      await _prefService.setString(_PREF_KEY_THEME, PREF_THEME_SYSTEM);
    }
  }

  static Future<bool> getSwipeToDelete() async {
    return await _prefService.getBool(_PREF_KEY_SWIPE_TO_DELETE);
  }

  static Future<void> setSwipeToDelete(bool swipeToDelete) async {
    await _prefService.setBool(_PREF_KEY_SWIPE_TO_DELETE, swipeToDelete);
  }
}


class _PreferenceService {
  Future<SharedPreferences>? _prefs;

  _PreferenceService() {
    _prefs = _init();
  }

  Future<SharedPreferences> _init () async {
    return SharedPreferences.getInstance();
  }

  Future<String> getString(String key) async {
    try {
      SharedPreferences prefs = await this._prefs!;
      return prefs.getString(key) ?? "";
    } catch (e) {
      return "";
    }
  }

  Future<void> setString(String key, String value) async {
    try {
      SharedPreferences prefs = await this._prefs!;
      prefs.setString(key, value);
    } catch (e) {
      // ignore
    }
  }

  Future<int> getInt(String key) async {
    try {
      SharedPreferences prefs = await this._prefs!;
      return prefs.getInt(key) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> setInt(String key, int value) async {
    try {
      SharedPreferences prefs = await this._prefs!;
      prefs.setInt(key, value);
    } catch (e) {
      // ignore
    }
  }

  Future<bool> getBool(String key) async {
    try {
      SharedPreferences prefs = await this._prefs!;
      return prefs.getBool(key) ?? true;
    } catch (e) {
      return true;
    }
  }

  Future<void> setBool(String key, bool value) async {
    try {
      SharedPreferences prefs = await this._prefs!;
      prefs.setBool(key, value);
    } catch (e) {
      // ignore
    }
  }

}