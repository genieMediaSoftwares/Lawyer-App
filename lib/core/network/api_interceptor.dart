import 'package:dio/dio.dart';
import '../storage/token_storage.dart';

class ApiInterceptor extends Interceptor {
  final TokenStorage _tokenStorage = TokenStorage();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStorage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return super.onRequest(options, handler);
  }
}
