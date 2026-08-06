import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _installReleaseLogSilencer();
  _installGlobalErrorHandlers();

  // A missing or unreadable .env used to throw straight out of main, which the
  // engine reports as a blank screen with no way for the user to act. The app
  // still needs a base URL to be useful, but failing here should surface as an
  // ordinary network error inside the UI rather than a launch that never
  // completes.
  try {
    await dotenv.load(fileName: ".env");
  } catch (error, stackTrace) {
    // Mark dotenv initialised with nothing in it. `dotenv.env` throws
    // NotInitializedError until a load succeeds, so without this the failure
    // would simply move: instead of dying here it would throw on the first
    // Environment.baseUrl read, deep inside the first screen. Empty is the
    // case Environment already handles — every getter has a default.
    dotenv.loadFromString(envString: '');

    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'main',
        context: ErrorDescription('loading .env configuration'),
      ),
    );
  }

  runApp(const ProviderScope(child: MyApp()));
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
