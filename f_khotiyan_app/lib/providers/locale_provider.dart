import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing app locale (English/Bangla)
class LocaleProvider with ChangeNotifier {
  static const String _localeKey = 'app_locale';

  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  bool get isBangla => _locale.languageCode == 'bn';

  /// Initialize locale from saved preference
  Future<void> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocale = prefs.getString(_localeKey);

    if (savedLocale != null) {
      _locale = Locale(savedLocale);
      notifyListeners();
    }
  }

  /// Toggle between English and Bangla
  Future<void> toggleLocale() async {
    _locale = _locale.languageCode == 'en'
        ? const Locale('bn')
        : const Locale('en');

    await _saveLocale();
    notifyListeners();
  }

  /// Set specific locale
  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    await _saveLocale();
    notifyListeners();
  }

  /// Save locale preference
  Future<void> _saveLocale() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, _locale.languageCode);
  }
}
