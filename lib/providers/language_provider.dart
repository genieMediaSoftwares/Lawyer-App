import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kLanguageKey = 'app_language_code';

class LanguageState {
  final String languageCode;
  final Locale locale;

  LanguageState({required this.languageCode})
      : locale = Locale(languageCode);

  LanguageState copyWith({String? languageCode}) {
    return LanguageState(
      languageCode: languageCode ?? this.languageCode,
    );
  }
}

class LanguageNotifier extends StateNotifier<LanguageState> {
  LanguageNotifier() : super(LanguageState(languageCode: 'en')) {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_kLanguageKey);
      if (savedCode != null && ['en', 'te', 'hi'].contains(savedCode)) {
        state = LanguageState(languageCode: savedCode);
      }
    } catch (e) {
      // fallback to English
    }
  }

  Future<void> setLanguage(String code) async {
    if (!['en', 'te', 'hi'].contains(code)) return;
    state = LanguageState(languageCode: code);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLanguageKey, code);
    } catch (e) {
      // ignore
    }
  }
}

final languageProvider =
    StateNotifierProvider<LanguageNotifier, LanguageState>((ref) {
  return LanguageNotifier();
});
