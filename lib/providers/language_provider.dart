import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/localization/locale_provider.dart';
import '../core/localization/locale_service.dart';

class LanguageState {
  final String languageCode;
  final Locale locale;

  LanguageState({required this.languageCode}) : locale = Locale(languageCode);

  LanguageState copyWith({String? languageCode}) {
    return LanguageState(languageCode: languageCode ?? this.languageCode);
  }
}

class LanguageNotifier extends StateNotifier<LanguageState> {
  final Ref _ref;
  final LocaleService _localeService = LocaleService();

  LanguageNotifier(this._ref) : super(LanguageState(languageCode: 'en')) {
    _init();
  }

  Future<void> _init() async {
    final savedLocale = await _localeService.getSavedLocale();
    state = LanguageState(languageCode: savedLocale.languageCode);
  }

  Future<void> setLanguage(String code) async {
    if (!_localeService.isSupported(code)) return;
    state = LanguageState(languageCode: code);
    await _ref.read(localeProvider.notifier).changeLanguage(Locale(code));
  }
}

final languageProvider = StateNotifierProvider<LanguageNotifier, LanguageState>(
  (ref) {
    return LanguageNotifier(ref);
  },
);
