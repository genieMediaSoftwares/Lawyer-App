import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Both before anything else can fail: the silencer decides what a release
  // build is allowed to write to the device log, and the error handlers are
  // the only path by which a failure during startup becomes visible at all.
  _installReleaseLogSilencer();
  _installGlobalErrorHandlers();

  // Configuration comes from .env, through AppConfig, and nowhere else.
  //
  // A .env that is missing, unreadable or incomplete is not fatal: AppConfig
  // fills the gaps from FallbackConfig and logs which keys it covered. Only a
  // *malformed* value — a non-numeric timeout, a relative URL — reaches the
  // catch below, along with anything at all when the build was compiled with
  // --dart-define=STRICT_ENV_CONFIG=true.
  //
  // Loading up front reports every problem at once, before any screen has a
  // chance to fail on whichever key it happens to touch first.
  try {
    await AppConfig.load();
  } on Object catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'main',
        context: ErrorDescription('loading .env configuration'),
      ),
    );

    // A bare `throw` here would surface as a white screen in a release build,
    // which is the opposite of a clear error. Show the reason on the device.
    runApp(_ConfigurationErrorApp(message: '$error'));
    return;
  }

  runApp(const ProviderScope(child: MyApp()));
}

/// Shown in place of the app when configuration cannot be satisfied.
class _ConfigurationErrorApp extends StatelessWidget {
  const _ConfigurationErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1B1B1F),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFFF6B6B),
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Configuration error',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFD7D7DC),
                    fontSize: 13,
                    height: 1.5,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sends framework and uncaught async errors through one path.
///
/// Without these, an error thrown inside a build or in an unawaited future is
/// either drawn as the grey error box or dropped entirely, and never reaches
/// anywhere it can be seen. Both now go to [FlutterError.presentError], which
/// prints in debug and is the single place to attach a crash reporter later.
void _installGlobalErrorHandlers() {
  final originalOnError = FlutterError.onError;

  FlutterError.onError = (FlutterErrorDetails details) {
    originalOnError?.call(details);
  };

  // Errors that escape the zone — a rejected future with no catch, a platform
  // channel failure. Returning true marks them handled so the process is not
  // torn down mid-session.
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'uncaught async error',
      ),
    );
    return true;
  };
}

/// Stops `debugPrint` writing to the device log in release builds.
///
/// `debugPrint` is not compiled out of a release build — the roughly forty
/// diagnostic calls across the app would otherwise be readable in logcat on any
/// user's device. Debug and profile builds keep the output.
void _installReleaseLogSilencer() {
  if (!kReleaseMode) return;
  debugPrint = (String? message, {int? wrapWidth}) {};

  // A widget that throws during build otherwise paints the framework's grey
  // error box, which reads as a broken app. Debug builds keep the red box with
  // the stack trace — this is only the release fallback.
  ErrorWidget.builder = (FlutterErrorDetails details) => const Material(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Something went wrong displaying this screen.\n'
              'Please go back and try again.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
}
