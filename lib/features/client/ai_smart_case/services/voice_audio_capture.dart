import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

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
/// are reported by the return value so a capture problem can never take the
/// transcript down with it.
class VoiceAudioCapture {
  VoiceAudioCapture({this.filePrefix = 'voice_case'});

  final String filePrefix;

  final AudioRecorder _recorder = AudioRecorder();

  bool _active = false;
  String? _path;

  bool get isActive => _active;

  /// Amplitude samples for a waveform, or an empty stream when not recording.
  Stream<Amplitude> amplitudes({
    Duration interval = const Duration(milliseconds: 100),
  }) {
    if (!_active) return const Stream<Amplitude>.empty();
    return _recorder.onAmplitudeChanged(interval);
  }

  /// Starts capture. Returns false when the platform cannot record — no
  /// filesystem (web), permission refused, or the microphone already held by
  /// speech recognition.
  Future<bool> start() async {
    if (_active) return true;

    // The clip is written to a temp file and handed back as a `dart:io` File;
    // neither exists in a browser.
    if (kIsWeb) return false;

    try {
      if (!await _recorder.hasPermission()) return false;

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/${filePrefix}_${DateTime.now().millisecondsSinceEpoch}.m4a';

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
      return true;
    } catch (e) {
      debugPrint('VoiceAudioCapture start failed: $e');
      _active = false;
      _path = null;
      return false;
    }
  }

  /// Stops capture and returns the file, or null if there is nothing usable.
  ///
  /// A clip under a kilobyte is a mis-tap or a microphone that was never
  /// actually granted, and is deleted rather than uploaded.
  Future<File?> stop({bool discard = false}) async {
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

  Future<void> dispose() async {
    if (_active) await stop(discard: true);
    try {
      await _recorder.dispose();
    } catch (e) {
      debugPrint('VoiceAudioCapture dispose failed: $e');
    }
  }
}
