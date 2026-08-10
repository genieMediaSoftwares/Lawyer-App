import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Structured logging for the AI Smart Case intake.
///
/// The intake spans an upload, a detached server pipeline, a Socket.IO stream
/// and an HTTP poll running concurrently. When a client reports "it just span
/// forever" there is no way to tell which of those stalled without a trace, so
/// every transition in this feature is logged through here.
///
/// Debug builds print to the console. Release builds keep only warnings and
/// errors, and route them through `dart:developer` so they land in the platform
/// log (logcat / os_log) and are picked up by whatever crash reporter is
/// attached, rather than being dropped.
class AILog {
  AILog._();

  static const _tag = 'AISmartCase';

  /// Correlates every line of one intake run. Set when a run starts.
  static String? _sessionId;

  // ignore: avoid_setters_without_getters
  static set session(String? id) => _sessionId = id;

  static void debug(String event, [Object? detail]) {
    if (!kDebugMode) return;
    developer.log(_format(event, detail), name: _tag, level: 500);
  }

  static void info(String event, [Object? detail]) {
    if (!kDebugMode) return;
    developer.log(_format(event, detail), name: _tag, level: 800);
  }

  static void warn(String event, [Object? detail]) {
    developer.log(_format(event, detail), name: _tag, level: 900);
  }

  static void error(String event, Object? err, [StackTrace? stack]) {
    developer.log(
      _format(event, err),
      name: _tag,
      level: 1000,
      error: err,
      stackTrace: stack,
    );
  }

  static String _format(String event, Object? detail) {
    final session = _sessionId;
    final scope = session == null ? '' : ' [${_short(session)}]';
    return detail == null ? '$event$scope' : '$event$scope — $detail';
  }

  /// Session ids are 24-character ObjectIds; the tail is enough to correlate
  /// lines and keeps them readable.
  static String _short(String id) => id.length <= 8 ? id : id.substring(id.length - 8);
}
