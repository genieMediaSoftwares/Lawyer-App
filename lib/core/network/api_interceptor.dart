import 'package:dio/dio.dart';
import '../storage/token_storage.dart';
import '../localization/locale_service.dart';

class ApiInterceptor extends Interceptor {
  final TokenStorage _tokenStorage = TokenStorage();
  final LocaleService _localeService = LocaleService();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Cache first. Every request would otherwise hit the platform keystore,
    // and a screen that fires several at once turns that into concurrent reads
    // of the same key — which is where the web backend intermittently fails
    // and a request goes out unauthenticated. The mirror is cleared on
    // sign-out, so this cannot resurrect a dead session.
    final token = TokenStorage.cachedToken ?? await _tokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    // Attach Accept-Language header to every API request
    final locale = await _localeService.getSavedLocale();
    options.headers['Accept-Language'] = locale.languageCode;

    return super.onRequest(options, handler);
  }
}
