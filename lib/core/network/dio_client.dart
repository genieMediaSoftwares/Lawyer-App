import 'dart:io';
import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/app_config.dart';
import '../errors/error_handler.dart';
import 'api_interceptor.dart';

class DioClient {
  DioClient._();

  static final Dio dio = _initDio();

  static Dio _initDio() {
    final client = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.httpConnectTimeout,
        receiveTimeout: AppConfig.httpReceiveTimeout,
        sendTimeout: AppConfig.httpSendTimeout,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
      ),
    );

    client.interceptors.addAll([
      ApiInterceptor(),
      RetryInterceptor(dio: client),
      ErrorInterceptor(),
    ]);

    if (AppConfig.httpLogRequests) {
      client.interceptors.add(
        PrettyDioLogger(
          requestBody: true,
          requestHeader: true,
          responseBody: true,
          responseHeader: false,
          error: true,
        ),
      );
    }
    return client;
  }
}

/// Set `extra: {noRetryKey: true}` on a request to exempt it from
/// [RetryInterceptor]'s backoff ladder.
const String noRetryKey = 'no_retry';

class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final Duration retryDelay;

  RetryInterceptor({
    required this.dio,
    int? maxRetries,
    Duration? retryDelay,
  })  : maxRetries = maxRetries ?? AppConfig.httpMaxRetries,
        retryDelay = retryDelay ?? AppConfig.httpRetryBaseDelay;

  static const _idempotentMethods = {'GET', 'HEAD', 'OPTIONS'};

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final requestOptions = err.requestOptions;

    // Check if the request is retryable (retry on timeouts or connection issues)
    final isRetryableError =
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.type == DioExceptionType.unknown && err.error is SocketException);

    final isIdempotent = _idempotentMethods.contains(
      requestOptions.method.toUpperCase(),
    );

    final neverReachedServer =
        err.type == DioExceptionType.connectionTimeout ||
        (err.type == DioExceptionType.unknown && err.error is SocketException);

    // A FormData body cannot be replayed. `finalize()` consumes its file
    // streams and throws "The FormData has already been finalized" on a second
    // read, so retrying one here either crashed the request or — worse, when
    // the throw was swallowed upstream — resent an empty body and the server
    // reported the upload as having no files at all. Multipart callers that
    // want retries have to rebuild the body per attempt, which the AI intake
    // upload does.
    final isReplayableBody = requestOptions.data is! FormData;

    // Opt-out for calls where a slow failure is worse than no answer at all.
    // Sign-out is the case in hand: it is best-effort by design, and grinding
    // through the full backoff ladder while offline would hold the user on the
    // screen they are trying to leave for over a minute.
    final optedOut = requestOptions.extra[noRetryKey] == true;

    final isRetryable = isRetryableError &&
        !optedOut &&
        isReplayableBody &&
        (isIdempotent || neverReachedServer);
    final retryCount = requestOptions.extra['retry_count'] ?? 0;

    if (isRetryable && retryCount < maxRetries) {
      requestOptions.extra['retry_count'] = retryCount + 1;

      await Future.delayed(retryDelay * (1 << (retryCount as int)));

      try {
        final response = await dio.request(
          requestOptions.path,
          data: requestOptions.data,
          queryParameters: requestOptions.queryParameters,
          cancelToken: requestOptions.cancelToken,
          options: Options(
            method: requestOptions.method,
            headers: requestOptions.headers,
            responseType: requestOptions.responseType,
            contentType: requestOptions.contentType,
            extra: requestOptions.extra,
          ),
          onSendProgress: requestOptions.onSendProgress,
          onReceiveProgress: requestOptions.onReceiveProgress,
        );
        return handler.resolve(response);
      } on DioException catch (retryErr) {
        return super.onError(retryErr, handler);
      }
    }

    return super.onError(err, handler);
  }
}

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Map the error using our unified ErrorHandler
    final mappedException = ErrorHandler.handleDioError(
      err,
      StackTrace.current,
    );

    // Reject with the mapped exception as the custom error object
    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: mappedException,
        message: mappedException.toString(),
      ),
    );
  }
}
