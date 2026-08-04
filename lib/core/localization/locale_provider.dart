import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'locale_service.dart';
import 'language_repository.dart';

class LocaleNotifier extends StateNotifier<Locale> {
  final LocaleService _localeService;
  final LanguageRepository _languageRepository;

  LocaleNotifier(this._localeService, this._languageRepository)
      : super(const Locale('en')) {
    _loadSavedLocale();
  }

  List<Locale> get supportedLocales => LocaleService.supportedLocales;

  Future<void> _loadSavedLocale() async {
    final savedLocale = await _localeService.getSavedLocale();
    state = savedLocale;
  }

  /// Change the global application language.
  /// 
  /// 1. Persists the language to SharedPreferences.
  /// 2. Updates Riverpod state immediately to trigger UI rebuild across entire app.
  /// 3. Calls backend endpoint to persist user language preference.
  Future<void> changeLanguage(Locale newLocale) async {
    final languageCode = newLocale.languageCode;
    if (!_localeService.isSupported(languageCode)) return;

    // 1. Save to SharedPreferences
    await _localeService.saveLocale(languageCode);

    // 2. Update state immediately (triggers app-wide rebuild)
    state = newLocale;

    // 3. Sync language preference to backend
    await _languageRepository.updateUserLanguage(languageCode);
  }

  /// Sets locale from backend data (e.g. during login or user payload sync)
  Future<void> setLocaleFromBackend(String languageCode) async {
    if (!_localeService.isSupported(languageCode)) return;
    await _localeService.saveLocale(languageCode);
    state = Locale(languageCode);
  }
}

final localeServiceProvider = Provider<LocaleService>((ref) {
  return LocaleService();
});

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  final service = ref.watch(localeServiceProvider);
  final repository = ref.watch(languageRepositoryProvider);
  return LocaleNotifier(service, repository);
});
