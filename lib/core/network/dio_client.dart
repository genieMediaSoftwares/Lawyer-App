import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/env.dart';
import '../errors/error_handler.dart';
import 'api_interceptor.dart';

class DioClient {
  DioClient._();

  static final Dio dio = _initDio();

  static Dio _initDio() {
    final client = Dio(
      BaseOptions(
        baseUrl: Environment.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
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

    // Debug builds only. This logs full request headers and bodies, which
    // includes the Authorization bearer token, plaintext passwords on
    // login/signup, and privileged case and document payloads — none of which
    // should reach the device log on a release build.
    if (kDebugMode) {
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

class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final Duration retryDelay;

  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 2),
  });

  /// Methods safe to replay. A retried POST/PUT/PATCH/DELETE can be applied
  /// twice when the server processed the first attempt but the response was
  /// lost — which is exactly what happened on `/ai/smart-case/analyze`: the
  /// client gave up at its receive timeout while the server kept working, and
  /// each retry created another session and another paid AI analysis.
  static const _idempotentMethods = {'GET', 'HEAD', 'OPTIONS'};

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final requestOptions = err.requestOptions;

    // Check if the request is retryable (retry on timeouts or connection issues)
    final isRetryableError = err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.type == DioExceptionType.unknown && err.error is SocketException);

    final isIdempotent =
        _idempotentMethods.contains(requestOptions.method.toUpperCase());

    // A connection timeout means the request never landed, so replaying a
    // write is still safe. Any later-stage timeout might have been served.
    final neverReachedServer =
        err.type == DioExceptionType.connectionTimeout ||
            (err.type == DioExceptionType.unknown && err.error is SocketException);

    final isRetryable =
        isRetryableError && (isIdempotent || neverReachedServer);

    final retryCount = requestOptions.extra['retry_count'] ?? 0;

    if (isRetryable && retryCount < maxRetries) {
      requestOptions.extra['retry_count'] = retryCount + 1;

      // Exponential backoff: 2s, 4s, 8s. A fixed delay hammers a service that
      // is already struggling.
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
    final mappedException = ErrorHandler.handleDioError(err, StackTrace.current);

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