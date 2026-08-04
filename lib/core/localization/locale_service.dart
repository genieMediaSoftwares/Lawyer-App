import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService {
  static const String _kLanguageKey = 'app_language_code';
  static const String defaultLanguageCode = 'en';

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('te'),
    Locale('hi'),
  ];

  /// Loads the saved locale code from SharedPreferences.
  /// Defaults to 'en' if not set or unsupported.
  Future<Locale> getSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_kLanguageKey);
      if (savedCode != null && isSupported(savedCode)) {
        return Locale(savedCode);
      }
    } catch (_) {
      // Fallback on failure
    }
    return const Locale(defaultLanguageCode);
  }

  /// Persists the specified locale code to SharedPreferences.
  Future<bool> saveLocale(String languageCode) async {
    if (!isSupported(languageCode)) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_kLanguageKey, languageCode);
    } catch (_) {
      return false;
    }
  }

  /// Helper to check if a language code is supported.
  bool isSupported(String languageCode) {
    return supportedLocales.any((loc) => loc.languageCode == languageCode);
  }
}
