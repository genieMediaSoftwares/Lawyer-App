import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:law/core/config/fallback_config.dart';
import 'package:law/core/network/dio_client.dart';

/// Prepares the environment every test in this directory runs against.
///
/// `flutter test` picks this file up automatically and wraps each test file
/// with it.
///
/// Two things are set up here.
///
/// **Configuration.** The app reads all of it through `AppConfig`, which throws
/// rather than inventing a default, so a widget or provider test that touches a
/// timeout, a limit or a URL needs a complete configuration — it previously saw
/// an empty string for every key and quietly carried on.
///
/// `FallbackConfig` is the base and the project's `.env` is layered on top, so
/// the suite is complete no matter what a given developer's `.env` says, or
/// whether it exists at all. That matters: `.env` is gitignored and routinely
/// half-commented while someone points the app at a local server, and no test
/// should start failing because of it. `app_config_test.dart` installs its own
/// values per case, so this baseline never hides a configuration bug.
///
/// **No network.** Several screens fetch during build. Pointing them at the
/// configured API would send traffic from every `flutter test` run to the real
/// backend, and the request never settles inside the test's fake clock, so the
/// framework reports a pending timer after teardown. The shared Dio instance
/// gets an adapter that refuses everything locally instead.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final envFile = File('.env');
  dotenv.loadFromString(
    envString: envFile.existsSync() ? envFile.readAsStringSync() : '',
    isOptional: true,
    mergeWith: FallbackConfig.values,
  );

  DioClient.dio.httpClientAdapter = _OfflineHttpClientAdapter();
  await testMain();
}

/// Answers every request with 503 without touching a socket.
///
/// 503 rather than a connection error on purpose: `RetryInterceptor` treats
/// connection failures as retryable and schedules a delayed retry, which is
/// itself a pending timer at teardown. A `badResponse` is final, so the request
/// settles on the first attempt.
class _OfflineHttpClientAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"message":"No backend is available in tests."}',
      503,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
