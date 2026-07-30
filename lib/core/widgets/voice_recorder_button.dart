import 'dart:async';
import 'dart:io';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../theme/app_colors.dart';

/// A small round microphone button that records audio and reports the result.
///
/// Owns the whole recording lifecycle — permission, encoder, timer, amplitude
/// stream, temp file — so screens do not have to. Two things matter about how
/// it is built:
///
/// 1. **Amplitude never triggers a `setState`.** The waveform is driven by a
///    [ValueNotifier] read through a [ValueListenableBuilder], so only the
///    bars repaint. The previous implementation called `setState` on every
///    amplitude sample (10 Hz) inside a 3,000-line screen, rebuilding the
///    entire form ten times a second — which is what made recording feel
///    broken and unresponsive.
/// 2. **The duration timer is separate from the amplitude stream**, and the
///    parent is only notified when recording starts and stops. A host screen
///    that persists a draft therefore writes once per recording rather than
///    once per second.
class VoiceRecorderButton extends StatefulWidget {
  /// Called with the recorded file once recording stops successfully.
  final ValueChanged<File> onRecordingComplete;

  /// Called when recording starts, and again when it ends or is cancelled.
  /// Lets the host show its own affordances without polling.
  final ValueChanged<bool>? onRecordingStateChanged;

  /// Hard cap on length. Recording auto-stops here rather than letting the
  /// user produce a file that will be rejected by the 10 MB upload limit.
  final Duration maxDuration;

  /// Diameter of the collapsed button. Kept at a 48dp minimum tap target by
  /// the surrounding [SizedBox] regardless of this value.
  final double size;

  /// Prefix for the generated temp filename, e.g. `case_desc`.
  final String filePrefix;

  const VoiceRecorderButton({
    super.key,
    required this.onRecordingComplete,
    this.onRecordingStateChanged,
    this.maxDuration = const Duration(minutes: 5),
    this.size = 36,
    this.filePrefix = 'voice_note',
  });

  @override
  State<VoiceRecorderButton> createState() => _VoiceRecorderButtonState();
}

class _VoiceRecorderButtonState extends State<VoiceRecorderButton> {
  final AudioRecorder _recorder = AudioRecorder();

  /// Rolling window of normalised levels (0..1), newest last.
  final ValueNotifier<List<double>> _levels = ValueNotifier(const []);
  final ValueNotifier<int> _elapsedSeconds = ValueNotifier(0);

  StreamSubscription<Amplitude>? _amplitudeSub;
  Timer? _timer;
  bool _isRecording = false;
  bool _isBusy = false;

  static const _barCount = 28;

  /// `record` reports amplitude in dBFS. Mapping from the full -160..0 range
  /// left normal speech (around -40 to -10 dB) bunched into the top quarter,
  /// so the waveform looked frozen. Clamping to a speech-relevant floor gives
  /// the bars visible dynamics.
  static const _minDb = -45.0;

  @override
  void dispose() {
    _timer?.cancel();
    _amplitudeSub?.cancel();
    _recorder.dispose();
    _levels.dispose();
    _elapsedSeconds.dispose();
    super.dispose();
  }

  double _normalise(double db) {
    if (db.isNaN || db.isInfinite) return 0;
    final clamped = db.clamp(_minDb, 0.0);
    return (clamped - _minDb) / -_minDb;
  }

  Future<void> _start() async {
    if (_isBusy) return;
    _isBusy = true;

    try {
      // Ask the recorder itself rather than going through permission_handler:
      // it resolves the correct permission per platform and reflects the
      // actual capture capability.
      if (!await _recorder.hasPermission()) {
        if (!mounted) return;
        _showMessage('Microphone permission is required to record.');
        return;
      }

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/${widget.filePrefix}_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          // Voice-grade settings. The default is music-oriented and produced
          // needlessly large files that pushed against the upload cap.
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );

      _levels.value = const [];
      _elapsedSeconds.value = 0;

      _amplitudeSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        // Notifier update only — no setState, so the host screen is untouched.
        final next = List<double>.of(_levels.value)..add(_normalise(amp.current));
        if (next.length > _barCount) next.removeAt(0);
        _levels.value = next;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _elapsedSeconds.value++;
        if (_elapsedSeconds.value >= widget.maxDuration.inSeconds) {
          _stop();
        }
      });

      if (!mounted) return;
      setState(() => _isRecording = true);
      widget.onRecordingStateChanged?.call(true);
    } catch (e) {
      if (mounted) _showMessage('Could not start recording. Please try again.');
      debugPrint('VoiceRecorderButton start failed: $e');
    } finally {
      _isBusy = false;
    }
  }

  Future<void> _stop({bool discard = false}) async {
    if (_isBusy) return;
    _isBusy = true;

    _timer?.cancel();
    await _amplitudeSub?.cancel();
    _timer = null;
    _amplitudeSub = null;

    try {
      final path = await _recorder.stop();

      if (mounted) setState(() => _isRecording = false);
      widget.onRecordingStateChanged?.call(false);

      if (path == null) return;

      final file = File(path);

      if (discard) {
        if (await file.exists()) await file.delete();
        return;
      }

      // A sub-second capture is almost always a mis-tap. Discard it rather
      // than sending an empty clip for transcription.
      if (!await file.exists() || await file.length() < 1024) {
        if (await file.exists()) await file.delete();
        if (mounted) _showMessage('That recording was too short.');
        return;
      }

      widget.onRecordingComplete(file);
    } catch (e) {
      if (mounted) setState(() => _isRecording = false);
      widget.onRecordingStateChanged?.call(false);
      debugPrint('VoiceRecorderButton stop failed: $e');
    } finally {
      _isBusy = false;
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _format(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isRecording) return _buildMicButton();
    return _buildRecordingBar();
  }

  /// Collapsed state: a small round gold mic button.
  Widget _buildMicButton() {
    return Semantics(
      button: true,
      label: 'Record a voice note',
      child: Tooltip(
        message: 'Record a voice note',
        child: InkWell(
          onTap: _start,
          customBorder: const CircleBorder(),
          // 48dp keeps the tap target at the platform minimum even though the
          // painted circle is smaller.
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryGold,
                ),
                child: Icon(
                  Icons.mic_rounded,
                  color: Colors.black,
                  size: widget.size * 0.55,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Recording state: live waveform, elapsed time, discard and stop.
  Widget _buildRecordingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: 'Discard recording',
            child: Tooltip(
              message: 'Discard',
              child: InkWell(
                onTap: () => _stop(discard: true),
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.delete_outline, color: Colors.white70, size: 20),
                ),
              ),
            ),
          ),
          ValueListenableBuilder<int>(
            valueListenable: _elapsedSeconds,
            builder: (_, seconds, __) => Text(
              _format(seconds),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Only these bars rebuild on each amplitude sample.
          ValueListenableBuilder<List<double>>(
            valueListenable: _levels,
            builder: (_, levels, __) => _Waveform(levels: levels, barCount: _barCount),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Stop recording',
            child: Tooltip(
              message: 'Stop',
              child: InkWell(
                onTap: () => _stop(),
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.redAccent,
                      ),
                      child: Icon(
                        Icons.stop_rounded,
                        color: Colors.white,
                        size: widget.size * 0.6,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Live level meter. Kept private and stateless so a rebuild is cheap.
class _Waveform extends StatelessWidget {
  final List<double> levels;
  final int barCount;

  const _Waveform({required this.levels, required this.barCount});

  @override
  Widget build(BuildContext context) {
    // Pad on the left so bars fill from the right as samples arrive.
    final padded = <double>[
      ...List<double>.filled((barCount - levels.length).clamp(0, barCount), 0.04),
      ...levels,
    ];

    return SizedBox(
      height: 28,
      width: barCount * 4.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final level in padded.take(barCount))
            Container(
              width: 2,
              height: 3 + (level * 25),
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: AppColors.primaryGold,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
      ),
    );
  }
}
