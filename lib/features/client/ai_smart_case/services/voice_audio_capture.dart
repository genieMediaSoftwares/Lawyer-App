import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Why capture could not start.
///
/// Each of these used to be a bare `false`, and the caller had one message for
/// all of them — "close anything else using the microphone" — which is the
/// remedy for exactly one and misleading for the rest.
enum VoiceCaptureFault {
  /// No filesystem to record to. Web only.
  unsupportedPlatform,

  /// The microphone permission is not granted.
  permissionDenied,

  /// The recorder itself refused to start: the microphone is held by a call or
  /// another app, or the encoder could not be created for this config.
  recorderFailed,
}

/// The outcome of [VoiceAudioCapture.start].
class VoiceCaptureResult {
  final bool started;
  final VoiceCaptureFault? fault;

  /// The platform's own words. For the log, never for a client.
  final String? detail;

  const VoiceCaptureResult.ok()
      : started = true,
        fault = null,
        detail = null;

  const VoiceCaptureResult.failed(this.fault, [this.detail]) : started = false;
}

/// Writes the microphone to a temporary `.m4a` file.
///
/// Extracted from the recording half of `VoiceRecorderButton` so the voice note
/// module can use the same capture settings without inheriting that widget's
/// UI. It has two jobs here:
///
///  * it *is* the voice note when live speech-to-text is unavailable on the
///    device, in which case the file is uploaded and the backend transcribes
///    it exactly as before; and
///  * it can run alongside live transcription to keep the original audio for
///    server-side validation — see `VoiceNoteRecorder.captureAudio` for why
///    that is off by default.
///
/// Every method is safe to call in any order and none of them throw; failures
/// are reported by the return value, or by [onFailure] for the ones the
/// platform only discovers after recording has begun.
class VoiceAudioCapture {
  VoiceAudioCapture({this.filePrefix = 'voice_case'});

  final String filePrefix;

  /// Built on first use, not on construction. `AudioRecorder()` registers
  /// itself with the platform from its constructor, so an eager field made
  /// every screen holding this class do platform work for a voice note the
  /// client may never record — and made the class impossible to subclass in a
  /// test without dragging the plugin in with it.
  AudioRecorder? _created;

  AudioRecorder get _recorder => _created ??= AudioRecorder();

  /// Called when capture fails *after* [start] has already succeeded.
  ///
  /// Android runs the capture on its own thread and reports a microphone it
  /// could not open — `PCM reader failed to initialize`, an unsupported sample
  /// rate, a device taken away mid-recording — on the recorder's state stream
  /// rather than by making `start` throw. Nothing listened to that stream, so
  /// those failures were invisible: the UI sat on "Recording…" and produced an
  /// empty file, which surfaced much later as "that recording was too short".
  void Function(String detail)? onFailure;

  bool _active = false;
  String? _path;
  StreamSubscription<RecordState>? _stateSub;

  bool get isActive => _active;

  /// Amplitude samples for a waveform, or an empty stream when not recording.
  Stream<Amplitude> amplitudes({
    Duration interval = const Duration(milliseconds: 100),
  }) {
    if (!_active) return const Stream<Amplitude>.empty();
    return _recorder.onAmplitudeChanged(interval);
  }

  /// Starts capture, naming the cause when it cannot.
  ///
  /// [permissionAlreadyGranted] skips `record`'s own permission gate. That gate
  /// answers with a bare bool, and its Android implementation answers `false`
  /// whenever the plugin has no activity bound — indistinguishable from a real
  /// refusal, logged nowhere, and enough on its own to report "recording could
  /// not be started" for a microphone the OS has in fact granted. A caller that
  /// has already settled the permission through `MicrophonePermission`, which
  /// reports *which* state it is in, has a better answer than this one and
  /// should pass true.
  Future<VoiceCaptureResult> start({bool permissionAlreadyGranted = false}) async {
    if (_active) return const VoiceCaptureResult.ok();

    // The clip is written to a temp file and handed back as a `dart:io` File;
    // neither exists in a browser.
    if (kIsWeb) {
      return const VoiceCaptureResult.failed(
        VoiceCaptureFault.unsupportedPlatform,
      );
    }

    if (!permissionAlreadyGranted) {
      try {
        if (!await _recorder.hasPermission()) {
          debugPrint('VoiceAudioCapture: recorder reports no microphone permission.');
          return const VoiceCaptureResult.failed(
            VoiceCaptureFault.permissionDenied,
          );
        }
      } catch (e) {
        debugPrint('VoiceAudioCapture permission check failed: $e');
        return VoiceCaptureResult.failed(
          VoiceCaptureFault.permissionDenied,
          '$e',
        );
      }
    }

    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/${filePrefix}_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Subscribed before starting, deliberately: `record` only forwards its
      // asynchronous errors while the state stream already has a listener.
      await _listenForFailures();

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          // Voice-grade, matching VoiceRecorderButton: the music-oriented
          // defaults produce files that push against the 10 MB upload cap.
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );

      _path = path;
      _active = true;
      return const VoiceCaptureResult.ok();
    } catch (e) {
      debugPrint('VoiceAudioCapture start failed: $e');
      await _stateSub?.cancel();
      _stateSub = null;
      _active = false;
      _path = null;
      return VoiceCaptureResult.failed(VoiceCaptureFault.recorderFailed, '$e');
    }
  }

  /// Stops capture and returns the file, or null if there is nothing usable.
  ///
  /// A clip under a kilobyte is a mis-tap or a microphone that was never
  /// actually granted, and is deleted rather than uploaded.
  Future<File?> stop({bool discard = false}) async {
    await _stateSub?.cancel();
    _stateSub = null;

    if (!_active) {
      if (discard) await _deleteFile();
      return null;
    }

    _active = false;

    try {
      final path = await _recorder.stop() ?? _path;
      _path = null;

      if (path == null) return null;
      final file = File(path);

      if (discard) {
        if (await file.exists()) await file.delete();
        return null;
      }

      if (!await file.exists() || await file.length() < 1024) {
        if (await file.exists()) await file.delete();
        return null;
      }

      return file;
    } catch (e) {
      debugPrint('VoiceAudioCapture stop failed: $e');
      return null;
    }
  }

  /// Deletes a file this capture produced. Best effort — a leftover temp file
  /// is the OS's problem, not the client's.
  Future<void> deleteFile(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('VoiceAudioCapture delete failed: $e');
    }
  }

  Future<void> _deleteFile() async {
    final path = _path;
    _path = null;
    if (path == null) return;
    await deleteFile(File(path));
  }

  /// Watches the recorder's state stream for the failures the platform only
  /// reports once capture is under way. Never throws — a stream that cannot be
  /// opened simply means this device reports nothing asynchronously.
  Future<void> _listenForFailures() async {
    await _stateSub?.cancel();
    _stateSub = null;

    try {
      _stateSub = _recorder.onStateChanged().listen(
        (_) {},
        onError: (Object e) {
          debugPrint('VoiceAudioCapture failed while recording: $e');
          onFailure?.call('$e');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('VoiceAudioCapture state stream unavailable: $e');
    }
  }

  Future<void> dispose() async {
    onFailure = null;
    if (_active) await stop(discard: true);
    await _stateSub?.cancel();
    _stateSub = null;

    // Nothing to release if the client never recorded — and building the
    // platform recorder here purely to tear it down would be the one thing the
    // lazy field above exists to avoid.
    final recorder = _created;
    _created = null;
    if (recorder == null) return;

    try {
      await recorder.dispose();
    } catch (e) {
      debugPrint('VoiceAudioCapture dispose failed: $e');
    }
  }
}
