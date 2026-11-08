import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences extends ChangeNotifier {
  AppPreferences(this._storage)
    : _language = switch (_storage.getString(_languageKey)) {
        'es' => AppLanguage.spanish,
        'en' => AppLanguage.english,
        _ => AppLanguage.system,
      },
      _darkTheme = _storage.getBool(_darkKey);

  static const _languageKey = 'app_language';
  static const _darkKey = 'app_dark_theme';

  final SharedPreferences _storage;
  AppLanguage _language;
  bool? _darkTheme;

  AppLanguage get language => _language;
  ThemeMode get themeMode => switch (_darkTheme) {
    true => ThemeMode.dark,
    false => ThemeMode.light,
    null => ThemeMode.system,
  };

  Future<void> setLanguage(AppLanguage language) async {
    _language = language;
    notifyListeners();
    await _storage.setString(_languageKey, language.locale?.languageCode ?? '');
  }

  Future<void> setDarkTheme(bool dark) async {
    _darkTheme = dark;
    notifyListeners();
    await _storage.setBool(_darkKey, dark);
  }
}
