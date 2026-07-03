import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:andsafe/utils/services/preferences_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Prefs.sortBy', () {
    test('defaults to title when not set', () async {
      expect(await Prefs.getSortBy(), PREF_SORT_KEY_TITLE);
    });

    test('returns valid sort key when set', () async {
      await Prefs.setSortBy(PREF_SORT_KEY_LAST_UPDATE);
      expect(await Prefs.getSortBy(), PREF_SORT_KEY_LAST_UPDATE);
    });

    test('rejects invalid sort key and defaults to title', () async {
      await Prefs.setSortBy('invalid_key');
      expect(await Prefs.getSortBy(), PREF_SORT_KEY_TITLE);
    });

    test('round-trip title', () async {
      await Prefs.setSortBy(PREF_SORT_KEY_TITLE);
      expect(await Prefs.getSortBy(), PREF_SORT_KEY_TITLE);
    });

    test('round-trip last_update', () async {
      await Prefs.setSortBy(PREF_SORT_KEY_LAST_UPDATE);
      expect(await Prefs.getSortBy(), PREF_SORT_KEY_LAST_UPDATE);
    });
  });

  group('Prefs.sortAscending', () {
    test('defaults to true when not set', () async {
      expect(await Prefs.isSortAscending(), isTrue);
    });

    test('returns set value', () async {
      await Prefs.setSortAscending(false);
      expect(await Prefs.isSortAscending(), isFalse);

      await Prefs.setSortAscending(true);
      expect(await Prefs.isSortAscending(), isTrue);
    });
  });

  group('Prefs.theme', () {
    test('defaults to system when not set', () async {
      expect(await Prefs.getSelectedTheme(), PREF_THEME_SYSTEM);
    });

    test('returns valid theme when set', () async {
      await Prefs.setSelectedTheme(PREF_THEME_LIGHT);
      expect(await Prefs.getSelectedTheme(), PREF_THEME_LIGHT);

      await Prefs.setSelectedTheme(PREF_THEME_DARK);
      expect(await Prefs.getSelectedTheme(), PREF_THEME_DARK);
    });

    test('rejects invalid theme and defaults to system', () async {
      await Prefs.setSelectedTheme('invalid_theme');
      expect(await Prefs.getSelectedTheme(), PREF_THEME_SYSTEM);
    });

    test('round-trip system', () async {
      await Prefs.setSelectedTheme(PREF_THEME_SYSTEM);
      expect(await Prefs.getSelectedTheme(), PREF_THEME_SYSTEM);
    });
  });

  group('Prefs.swipeToDelete', () {
    test('defaults to true when not set', () async {
      expect(await Prefs.getSwipeToDelete(), isTrue);
    });

    test('returns set value', () async {
      await Prefs.setSwipeToDelete(false);
      expect(await Prefs.getSwipeToDelete(), isFalse);

      await Prefs.setSwipeToDelete(true);
      expect(await Prefs.getSwipeToDelete(), isTrue);
    });
  });

  group('Prefs.biometricEnabled', () {
    test('defaults to false when not set', () async {
      expect(await Prefs.getBiometricEnabled(), isFalse);
    });

    test('returns set value', () async {
      await Prefs.setBiometricEnabled(true);
      expect(await Prefs.getBiometricEnabled(), isTrue);

      await Prefs.setBiometricEnabled(false);
      expect(await Prefs.getBiometricEnabled(), isFalse);
    });
  });

  group('Prefs.biometricOffered', () {
    test('defaults to false when not set', () async {
      expect(await Prefs.getBiometricOffered(), isFalse);
    });

    test('returns set value', () async {
      await Prefs.setBiometricOffered(true);
      expect(await Prefs.getBiometricOffered(), isTrue);

      await Prefs.setBiometricOffered(false);
      expect(await Prefs.getBiometricOffered(), isFalse);
    });
  });

  group('constants', () {
    test('sort key constants', () {
      expect(PREF_SORT_KEY_TITLE, 'title');
      expect(PREF_SORT_KEY_LAST_UPDATE, 'last_update');
    });

    test('theme constants', () {
      expect(PREF_THEME_SYSTEM, 'system');
      expect(PREF_THEME_LIGHT, 'light');
      expect(PREF_THEME_DARK, 'dark');
    });
  });
}
