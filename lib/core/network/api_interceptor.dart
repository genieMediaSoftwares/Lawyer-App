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
    final token = await _tokenStorage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    // Attach Accept-Language header to every API request
    final locale = await _localeService.getSavedLocale();
    options.headers['Accept-Language'] = locale.languageCode;

    return super.onRequest(options, handler);
  }
}
