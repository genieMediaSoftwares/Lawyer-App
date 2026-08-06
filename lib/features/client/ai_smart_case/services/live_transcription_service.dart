import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Why live transcription could not start, or stopped.
///
/// The fault is what the UI branches on; [VoiceTranscriptionFailure.message] is
/// what it shows. Nothing here is ever thrown at the caller — every failure
/// arrives through the [LiveTranscriptionService.onFailure] callback.
enum VoiceTranscriptionFault {
  /// The client refused, or previously refused, microphone access.
  permissionDenied,

  /// No speech recognition service on this device (no Google app, an
  /// unsupported OS, a desktop/web target). Recoverable only by falling back
  /// to record-and-transcribe-server-side.
  unavailable,

  /// Recognition needs the network and it is not reachable.
  network,

  /// The recogniser is held by another app, or by a call in progress.
  busy,

  /// Listening ran but nothing intelligible was said.
  noSpeech,

  unknown,
}

/// A recognition failure, already phrased for a client to read.
class VoiceTranscriptionFailure {
  final VoiceTranscriptionFault fault;
  final String message;

  /// Permanent faults end the session. Transient ones are recovered from
  /// internally and never reach the UI.
  final bool permanent;

  const VoiceTranscriptionFailure(
    this.fault,
    this.message, {
    this.permanent = true,
  });
}

/// Continuous on-device speech-to-text for the AI Smart Case voice note.
///
/// Wraps `speech_to_text`, which is session-based: every platform recogniser
/// ends its own listen session after a silence or a time limit, and iOS caps a
/// single recognition task at around a minute. A voice note describing a legal
/// matter runs far longer than that, so this service treats those endings as
/// normal, commits the words recognised so far and starts the next session —
/// the client sees one uninterrupted transcript.
///
/// Three properties matter to the callers:
///
///  1. **The transcript is never lost to a restart.** Finalised segments are
///     accumulated in [_committed]; only the in-flight segment is volatile.
///  2. **Transient faults never surface.** A silence timeout or an empty
///     result restarts listening silently. Only a permanent fault — no
///     permission, no recogniser, repeated start failures — reaches
///     [onFailure], and only then does the session end.
///  3. **Stopping does not block on the platform.** [stop] returns the text
///     already recognised after a short grace period for the trailing final
///     result, so the UI can go straight to an editable transcript.
class LiveTranscriptionService {
  LiveTranscriptionService({SpeechToText? speech})
      : _speech = speech ?? SpeechToText();

  /// `SpeechToText()` is an app-wide singleton, so this service must always
  /// leave it in a clean state — see [dispose].
  final SpeechToText _speech;

  /// Per-session cap. iOS ends a recognition task on its own at roughly a
  /// minute; restarting just under that is smoother than being cut off.
  static const _sessionLimit = Duration(seconds: 50);

  /// Plugin-level silence timeout. Deliberately long: the platform recogniser
  /// applies its own much shorter one, and this only exists so a client
  /// pausing to think is not treated as finished.
  static const _pauseFor = Duration(seconds: 12);

  /// Breathing room between sessions. Restarting the recogniser in the same
  /// turn as its `done` callback fails on several Android builds.
  static const _restartDelay = Duration(milliseconds: 220);

  /// How long the plugin waits after a stop for the device to send a final
  /// result before promoting the last partial to one itself.
  ///
  /// Shortened from the two second default so that promotion happens inside
  /// [_finalGrace] rather than a second after [stop] has already returned —
  /// a late final result is only useful if it can still be shown.
  static const _finalTimeout = Duration(milliseconds: 700);

  /// How long [stop] waits for the trailing final result before returning what
  /// it already has. Must outlast [_finalTimeout].
  static const _finalGrace = Duration(milliseconds: 900);

  /// Consecutive failed `listen` calls before the session is given up on.
  static const _maxFailedStarts = 3;

  /// Called on every transcript change, partial results included.
  void Function(String transcript)? onTranscript;

  /// Normalised 0..1 microphone level, for the waveform.
  void Function(double level)? onSoundLevel;

  /// Called when listening actually starts and when it ends.
  void Function(bool listening)? onListeningChanged;

  /// Called for permanent faults only.
  void Function(VoiceTranscriptionFailure failure)? onFailure;

  bool _initialised = false;
  bool _initialising = false;

  /// True between [start] and [stop]/[cancel]. Restarts happen inside it.
  bool _sessionOpen = false;

  /// Set by [stop]/[cancel] so an in-flight `done` callback does not restart.
  bool _stopRequested = false;

  bool _restartPending = false;
  int _failedStarts = 0;

  String _committed = '';
  String _partial = '';

  String? _localeId;
  List<LocaleName>? _localeCache;

  Timer? _restartTimer;
  Timer? _graceTimer;
  Completer<String>? _finalCompleter;

  /// Everything recognised so far, finalised segments plus the in-flight one.
  String get transcript {
    final parts = [_committed.trim(), _partial.trim()].where((p) => p.isNotEmpty);
    return parts.join(' ');
  }

  bool get isListening => _sessionOpen && !_stopRequested;

  /// True once the platform has confirmed a recogniser exists.
  bool get isAvailable => _initialised;

  /// Begins listening.
  ///
  /// [preferredLocales] are tried in order against the locales the device
  /// actually supports — pass the app's current language first. [seed] carries
  /// an existing transcript forward, which is how "add more" appends to text
  /// the client has already recorded and possibly edited.
  ///
  /// Returns false if listening could not start; [onFailure] has already
  /// described why.
  Future<bool> start({
    List<String> preferredLocales = const [],
    String seed = '',
  }) async {
    if (_sessionOpen) return true;

    _stopRequested = false;
    _failedStarts = 0;
    _committed = seed.trim();
    _partial = '';
    _emitTranscript();

    if (!await _ensureInitialised()) return false;

    // Resolved per start rather than cached for the life of the service: the
    // client may have changed the app language since the last recording.
    _localeId = await _resolveLocale(preferredLocales);

    _sessionOpen = true;
    final started = await _listen(isRestart: false);
    if (!started) {
      _sessionOpen = false;
      onListeningChanged?.call(false);
    }
    return started;
  }

  /// Ends the session and returns the finished transcript.
  ///
  /// Waits at most [_finalGrace] for the platform's trailing final result, so
  /// the caller can show an editable transcript immediately instead of sitting
  /// on a spinner. A final result that lands after the grace period still
  /// reaches [onTranscript].
  Future<String> stop() async {
    if (!_sessionOpen) return transcript;

    _stopRequested = true;
    _cancelTimers();

    final completer = Completer<String>();
    _finalCompleter = completer;

    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('LiveTranscriptionService stop failed: $e');
    }

    _sessionOpen = false;
    onListeningChanged?.call(false);

    _graceTimer = Timer(_finalGrace, () {
      if (!completer.isCompleted) completer.complete(transcript);
    });

    return completer.future;
  }

  /// Ends the session and throws the transcript away.
  Future<void> cancel() async {
    _stopRequested = true;
    _cancelTimers();
    _completeFinal();

    if (_sessionOpen) {
      try {
        await _speech.cancel();
      } catch (e) {
        debugPrint('LiveTranscriptionService cancel failed: $e');
      }
      _sessionOpen = false;
      onListeningChanged?.call(false);
    }

    _committed = '';
    _partial = '';
  }

  /// Releases the shared recogniser and drops every callback.
  ///
  /// Both halves matter. `SpeechToText` is a process-wide singleton whose
  /// `errorListener`/`statusListener` are plain fields, and `initialize()`
  /// returns early once it has succeeded without re-registering them — so a
  /// service that did not clear them would keep receiving callbacks into a
  /// disposed widget's closures for the rest of the app's life.
  Future<void> dispose() async {
    await cancel();

    onTranscript = null;
    onSoundLevel = null;
    onListeningChanged = null;
    onFailure = null;

    if (_speech.errorListener == _onError) _speech.errorListener = null;
    if (_speech.statusListener == _onStatus) _speech.statusListener = null;
  }

  // ── internals ────────────────────────────────────────────────────────────

  Future<bool> _ensureInitialised({bool reportFailure = true}) async {
    if (_initialised) {
      _attachListeners();
      return true;
    }
    if (_initialising) return false;

    _initialising = true;
    try {
      final worked = await _speech.initialize(
        onError: _onError,
        onStatus: _onStatus,
        finalTimeout: _finalTimeout,
        // Some Android builds ship without a properly declared recognition
        // intent; the lookup workaround is the difference between working and
        // "speech recognition unavailable" on those devices.
        options: [SpeechToText.androidIntentLookup],
      );

      _initialised = worked;
      if (worked) {
        _attachListeners();
      } else if (reportFailure) {
        // `initialize` returns false both when the client denied the
        // microphone and when no recogniser exists. Ask which it was rather
        // than guessing, so the message matches the fix.
        final permitted = await _hasPermission();
        _fail(permitted
            ? const VoiceTranscriptionFailure(
                VoiceTranscriptionFault.unavailable,
                'Live transcription is not available on this device. '
                'You can still record a voice note and we will transcribe it after upload.',
              )
            : const VoiceTranscriptionFailure(
                VoiceTranscriptionFault.permissionDenied,
                'Microphone access is needed to record a voice note. '
                'Please allow it in your device settings and try again.',
              ));
      }
      return worked;
    } catch (e) {
      debugPrint('LiveTranscriptionService initialize failed: $e');
      if (reportFailure) {
        _fail(const VoiceTranscriptionFailure(
          VoiceTranscriptionFault.unavailable,
          'Live transcription could not be started on this device. '
          'You can still record a voice note and we will transcribe it after upload.',
        ));
      }
      return false;
    } finally {
      _initialising = false;
    }
  }

  /// Re-points the singleton's listeners at this service. Required on every
  /// path into listening, not just the first — see [dispose].
  void _attachListeners() {
    _speech.errorListener = _onError;
    _speech.statusListener = _onStatus;
  }

  Future<bool> _hasPermission() async {
    try {
      return await _speech.hasPermission;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _resolveLocale(List<String> preferred) async {
    try {
      _localeCache ??= await _speech.locales();
      final available = _localeCache!;
      if (available.isEmpty) return null;

      for (final wanted in preferred) {
        final needle = wanted.toLowerCase().replaceAll('-', '_');
        // Exact match first, then language-only (`hi` matching `hi_IN`), so a
        // device that only carries a regional variant is still used.
        final exact = available.where((l) =>
            l.localeId.toLowerCase().replaceAll('-', '_') == needle);
        if (exact.isNotEmpty) return exact.first.localeId;

        final language = needle.split('_').first;
        final loose = available.where((l) =>
            l.localeId.toLowerCase().replaceAll('-', '_').split('_').first ==
            language);
        if (loose.isNotEmpty) return loose.first.localeId;
      }

      final system = await _speech.systemLocale();
      return system?.localeId;
    } catch (e) {
      debugPrint('LiveTranscriptionService locale lookup failed: $e');
      return null;
    }
  }

  Future<bool> _listen({bool isRestart = true}) async {
    try {
      // Close the previous session's bookkeeping before opening the next one.
      //
      // A restart follows a session the *platform* ended, so the plugin never
      // ran its own shutdown: its pause/listen-limit timer is still armed, and
      // `listen` overwrites the field holding it rather than cancelling it. One
      // orphaned timer accumulated per restart — dozens over a long dictation —
      // each able to fire `_stop()` against the session then running and cut
      // the client off mid-sentence. `stop` runs that shutdown and cancels it.
      if (isRestart) {
        try {
          await _speech.stop();
        } catch (e) {
          debugPrint('LiveTranscriptionService pre-restart stop failed: $e');
        }
      }

      await _speech.listen(
        onResult: _onResult,
        onSoundLevelChange: _onSoundLevel,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          // Transient faults are handled here by restarting; letting the
          // plugin cancel on them would end a session mid-sentence.
          cancelOnError: false,
          listenMode: ListenMode.dictation,
          localeId: _localeId,
          autoPunctuation: true,
          enableHapticFeedback: false,
          listenFor: _sessionLimit,
          pauseFor: _pauseFor,
        ),
      );
      _failedStarts = 0;
      return true;
    } catch (e) {
      debugPrint('LiveTranscriptionService listen failed: $e');
      _failedStarts++;
      if (_failedStarts >= _maxFailedStarts) {
        _endWithFailure(const VoiceTranscriptionFailure(
          VoiceTranscriptionFault.busy,
          'The microphone could not be started. Close any other app using it and try again.',
        ));
      }
      return false;
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    _partial = result.recognizedWords;

    if (result.finalResult) {
      _commitPartial();
      if (_stopRequested) _completeFinal();
    }

    _emitTranscript();
  }

  void _onSoundLevel(double level) {
    if (level.isNaN || level.isInfinite) return;
    onSoundLevel?.call(_normaliseLevel(level));
  }

  /// Android reports dBFS (roughly -2..10 from `SpeechRecognizer`), iOS a
  /// small positive magnitude. Clamping to a speech-relevant band keeps the
  /// waveform moving on both instead of pinning to one end.
  double _normaliseLevel(double level) {
    const floor = -2.0;
    const ceiling = 10.0;
    final clamped = level.clamp(floor, ceiling);
    return ((clamped - floor) / (ceiling - floor)).clamp(0.0, 1.0);
  }

  void _onStatus(String status) {
    if (status == SpeechToText.listeningStatus) {
      onListeningChanged?.call(true);
      return;
    }

    // `notListening` then `done` both arrive at the end of a session; only
    // `done` means the platform has finished delivering results, so restarting
    // on anything earlier would race the final result.
    if (status != SpeechToText.doneStatus) return;

    if (_stopRequested || !_sessionOpen) {
      onListeningChanged?.call(false);
      return;
    }

    _scheduleRestart();
  }

  void _onError(SpeechRecognitionError error) {
    final failure = _classify(error);

    if (!failure.permanent) {
      // A silence timeout or an unrecognised phrase is an ordinary part of a
      // long dictation. Keep the transcript and listen again.
      if (_sessionOpen && !_stopRequested) _scheduleRestart();
      return;
    }

    _endWithFailure(failure);
  }

  VoiceTranscriptionFailure _classify(SpeechRecognitionError error) {
    final msg = error.errorMsg.toLowerCase();

    if (msg.contains('no_match') || msg.contains('speech_timeout')) {
      return const VoiceTranscriptionFailure(
        VoiceTranscriptionFault.noSpeech,
        'No speech detected.',
        permanent: false,
      );
    }

    if (msg.contains('permission')) {
      return const VoiceTranscriptionFailure(
        VoiceTranscriptionFault.permissionDenied,
        'Microphone access is needed to record a voice note. '
        'Please allow it in your device settings and try again.',
      );
    }

    if (msg.contains('network')) {
      return const VoiceTranscriptionFailure(
        VoiceTranscriptionFault.network,
        'Speech recognition needs an internet connection. '
        'Check your connection and try again.',
      );
    }

    if (msg.contains('busy')) {
      return const VoiceTranscriptionFailure(
        VoiceTranscriptionFault.busy,
        'The microphone is in use by another app. Close it and try again.',
      );
    }

    if (msg.contains('language')) {
      return const VoiceTranscriptionFailure(
        VoiceTranscriptionFault.unavailable,
        'This language is not supported for live transcription on your device. '
        'You can still record a voice note and we will transcribe it after upload.',
      );
    }

    if (msg.contains('audio') || msg.contains('client')) {
      // Recoverable on the next session on most devices — a brief audio route
      // change, a notification sound, a Bluetooth headset connecting.
      return const VoiceTranscriptionFailure(
        VoiceTranscriptionFault.unknown,
        'Recording was interrupted.',
        permanent: false,
      );
    }

    return VoiceTranscriptionFailure(
      VoiceTranscriptionFault.unknown,
      'Speech recognition stopped unexpectedly. Please try again.',
      permanent: error.permanent,
    );
  }

  void _scheduleRestart() {
    if (_restartPending || _stopRequested || !_sessionOpen) return;

    _restartPending = true;
    _commitPartial();

    _restartTimer = Timer(_restartDelay, () async {
      _restartPending = false;
      if (_stopRequested || !_sessionOpen) return;

      final started = await _listen();
      // A single failed restart is retried on the next tick; only a run of
      // them ends the session, which _listen handles.
      if (!started && _sessionOpen && !_stopRequested) _scheduleRestart();
    });
  }

  /// Moves the in-flight segment into the finalised transcript.
  void _commitPartial() {
    final segment = _partial.trim();
    _partial = '';
    if (segment.isEmpty) return;
    _committed = _committed.isEmpty ? segment : '$_committed $segment';
  }

  void _endWithFailure(VoiceTranscriptionFailure failure) {
    _stopRequested = true;
    _cancelTimers();
    _commitPartial();

    if (_sessionOpen) {
      _sessionOpen = false;
      _speech.cancel().catchError(
            (Object e) => debugPrint('LiveTranscriptionService cancel failed: $e'),
          );
      onListeningChanged?.call(false);
    }

    _completeFinal();
    _emitTranscript();
    _fail(failure);
  }

  void _fail(VoiceTranscriptionFailure failure) => onFailure?.call(failure);

  void _completeFinal() {
    final completer = _finalCompleter;
    _finalCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(transcript);
    }
  }

  void _emitTranscript() => onTranscript?.call(transcript);

  void _cancelTimers() {
    _restartTimer?.cancel();
    _restartTimer = null;
    _graceTimer?.cancel();
    _graceTimer = null;
    _restartPending = false;
  }
}
