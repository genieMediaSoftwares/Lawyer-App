import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:logger/logger.dart';
import 'exceptions.dart';

class ErrorHandler {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
    ),
  );

  /// Header and body keys whose values must never reach a log.
  ///
  /// `Authorization` is the live bearer token for the signed-in user, and the
  /// login and reset payloads carry the password in plain text.
  static const _sensitiveKeys = {
    'authorization',
    'cookie',
    'set-cookie',
    'token',
    'accesstoken',
    'refreshtoken',
    'password',
    'newpassword',
    'currentpassword',
    'confirmpassword',
    'otp',
    'pin',
    'upiid',
    'accountnumber',
    'ifsccode',
  };

  /// Replaces sensitive values with a marker, leaving the shape intact so a
  /// log still shows which fields were sent.
  static Object? _redact(Object? value) {
    if (value is Map) {
      return value.map(
        (key, dynamic v) => MapEntry(
          key,
          _sensitiveKeys.contains(key.toString().toLowerCase().replaceAll('_', ''))
              ? '<redacted>'
              : _redact(v),
        ),
      );
    }
    if (value is List) return value.map(_redact).toList();
    return value;
  }

  /// Logs the failure in detail — in debug builds only.
  ///
  /// This used to run in every build and dumped the request headers and body
  /// verbatim, which put the signed-in user's bearer token, and their password
  /// on any failed login, into the device log where any process able to read
  /// logcat could collect them. The mapping done by [handleDioError] is
  /// unchanged; only the logging is gated and redacted.
  static void logDioException(DioException exception, StackTrace stackTrace) {
    if (!kDebugMode) return;

    final requestOptions = exception.requestOptions;
    final response = exception.response;

    final Map<String, dynamic> errorLog = {
      'URL': requestOptions.uri.toString(),
      'Method': requestOptions.method,
      'Headers': _redact(requestOptions.headers),
      'Request Data': _redact(requestOptions.data),
      'Status Code': response?.statusCode,
      'Response Headers': _redact(response?.headers.map),
      'Response Data': _redact(response?.data),
      'Exception Message': exception.message,
      'Exception Type': exception.type.toString(),
      'Error Object': exception.error.toString(),
    };

    _logger.e(
      '🚨 DIO EXCEPTION DETECTED\n'
      '--------------------------------------------------\n'
      'URL: ${errorLog['URL']}\n'
      'Method: ${errorLog['Method']}\n'
      'Status Code: ${errorLog['Status Code']}\n'
      'Response Body: ${errorLog['Response Data']}\n'
      'Request Body: ${errorLog['Request Data']}\n'
      'Headers: ${errorLog['Headers']}\n'
      '--------------------------------------------------',
      error: exception,
      stackTrace: stackTrace,
    );
  }

  static Exception handleDioError(DioException error, StackTrace stackTrace) {
    logDioException(error, stackTrace);

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return NetworkException(
          "Connection timed out. Please check your internet connection.",
        );
      case DioExceptionType.sendTimeout:
        return NetworkException("Send timeout. Please try again.");
      case DioExceptionType.receiveTimeout:
        return NetworkException(
          "Receive timeout. Server is taking too long to respond.",
        );
      case DioExceptionType.badCertificate:
        return ServerException(
          "Secure connection failed. Invalid SSL certificate.",
        );
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final responseData = error.response?.data;
        String? serverMsg;
        if (responseData is Map) {
          serverMsg =
              responseData['message']?.toString() ??
              responseData['error']?.toString();
        }

        if (statusCode == 400) {
          return ServerException(
            serverMsg ?? "Bad Request. Please check your inputs.",
          );
        } else if (statusCode == 401) {
          return ServerException(
            serverMsg ?? "Unauthorized. Please login again.",
          );
        } else if (statusCode == 403) {
          return ServerException(
            serverMsg ?? "Access forbidden. You do not have permission.",
          );
        } else if (statusCode == 404) {
          return ServerException(
            serverMsg ?? "Resource not found on the server.",
          );
        } else if (statusCode == 500) {
          return ServerException(
            serverMsg ?? "Internal Server Error. Please try again later.",
          );
        }
        return ServerException(
          serverMsg ?? "Server returned error: $statusCode",
        );

      case DioExceptionType.cancel:
        return ServerException("Request was cancelled.");
      case DioExceptionType.connectionError:
        if (error.error is SocketException) {
          final socketError = error.error as SocketException;
          return NetworkException(
            "Connection failed: ${socketError.message}. Ensure your device is on the same network as the server.",
          );
        }
        return NetworkException(
          "Connection failed. Please check if the server is running and reachable.",
        );
      case DioExceptionType.unknown:
        if (error.error is SocketException) {
          final socketError = error.error as SocketException;
          return NetworkException(
            "Network error: ${socketError.message}. Please check your connection.",
          );
        }
        return ServerException(
          "An unexpected error occurred: ${error.message}",
        );
      default:
        return ServerException("An unexpected network error occurred.");
    }
  }
}
