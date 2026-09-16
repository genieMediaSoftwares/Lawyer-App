import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// Renews an expired access token and replays the request that hit the 401.
///
/// The access token is short-lived and the refresh token is not, so the normal
/// end of a token's life is a single 401 that nobody should ever see. This
/// turns that 401 into a refresh and a retry.
///
/// Two properties matter more than the happy path:
///
///  * **One refresh at a time.** A screen that fires five requests at once gets
///    five 401s at once. Refreshing five times would rotate the refresh token
///    five times, and because rotation invalidates the token it replaces, four
///    of those would be spending a token that had already been spent — the
///    device would log itself out. [_inFlight] makes the first caller do the
///    work and the rest await its result.
///
///  * **Retry exactly once.** A request is replayed only if it has not been
///    replayed before, so a genuinely revoked session ends in one clean 401
///    rather than a loop.
///
/// Signing out is left to the caller. This interceptor never clears the
/// session on its own — a network blip during a refresh is not proof that the
/// session is gone, and treating it as such is how a user gets ejected mid-task.
/// It reports failure by letting the original 401 through, and
/// [onRefreshFailed] fires only when the server actually rejected the refresh
/// token.
class AuthRefreshInterceptor extends Interceptor {
  AuthRefreshInterceptor({
    required this.dio,
    required this.refreshEndpoint,
    this.onRefreshFailed,
  });

  /// The client whose requests this guards, used to replay the retried call.
  final Dio dio;

  /// Path of the refresh route, relative to the Dio base URL.
  final String refreshEndpoint;

  /// Called when the server rejects the refresh token, i.e. the session is
  /// genuinely over. Not called for network or server errors.
  final Future<void> Function()? onRefreshFailed;

  final TokenStorage _tokenStorage = TokenStorage();

  /// The refresh currently running, shared by everyone waiting on it.
  Future<String?>? _inFlight;

  /// Marks a request this interceptor has already replayed.
  static const String _retriedFlag = 'auth_refresh_retried';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final request = err.requestOptions;

    final isAuthFailure = response?.statusCode == 401;
    final alreadyRetried = request.extra[_retriedFlag] == true;

    // Refreshing the refresh call itself would recurse.
    final isRefreshCall = request.path.contains(refreshEndpoint);

    if (!isAuthFailure || alreadyRetried || isRefreshCall) {
      return handler.next(err);
    }

    final token = await _refresh();

    if (token == null || token.isEmpty) {
      return handler.next(err);
    }

    try {
      final retried = await dio.fetch<dynamic>(
        request
          ..headers['Authorization'] = 'Bearer $token'
          ..extra[_retriedFlag] = true,
      );
      return handler.resolve(retried);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  /// Runs one refresh, or joins the one already running.
  Future<String?> _refresh() {
    final running = _inFlight;
    if (running != null) return running;

    final attempt = _performRefresh().whenComplete(() => _inFlight = null);
    _inFlight = attempt;
    return attempt;
  }

  Future<String?> _performRefresh() async {
    final refreshToken =
        TokenStorage.cachedRefreshToken ?? await _tokenStorage.getRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    try {
      // A bare Dio: the app's own instance carries this interceptor, and the
      // request must not be able to trigger another refresh.
      final client = Dio(BaseOptions(baseUrl: dio.options.baseUrl));

      final response = await client.post<dynamic>(
        refreshEndpoint,
        data: {'refreshToken': refreshToken},
      );

      final body = response.data;
      final data = body is Map ? body['data'] : null;
      if (data is! Map) return null;

      final token = (data['token'] ?? '').toString();
      final nextRefreshToken = (data['refreshToken'] ?? '').toString();

      if (token.isEmpty) return null;

      await _tokenStorage.saveToken(token);
      // The server rotates on every successful refresh, so the old value is
      // already dead. Failing to store the new one would cost the session.
      if (nextRefreshToken.isNotEmpty) {
        await _tokenStorage.saveRefreshToken(nextRefreshToken);
      }

      return token;
    } on DioException catch (e) {
      // 401 means the refresh token itself was rejected: revoked, expired or
      // already spent. That is a real end of session. Anything else — no
      // network, a 500, a timeout — is not, and must not sign the user out.
      if (e.response?.statusCode == 401) {
        await onRefreshFailed?.call();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
