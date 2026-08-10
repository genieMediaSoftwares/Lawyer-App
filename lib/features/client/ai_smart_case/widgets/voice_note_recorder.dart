import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:record/record.dart' show Amplitude;

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../services/live_transcription_service.dart';
import '../services/voice_audio_capture.dart';

/// Which engine is driving the current recording.
enum _Engine {
  /// On-device speech-to-text: words appear while the client speaks.
  live,

  /// No recogniser on this device — record the audio and let the backend
  /// transcribe it after upload, exactly as this feature used to.
  audioOnly,
}

enum _Stage { idle, listening, review }

/// The AI Smart Case voice note: speak, watch the words appear, edit, submit.
///
/// Optional by design. The uploaded documents remain the primary source the
/// assistant reasons from; this only adds context the documents do not carry,
/// which is why every failure path here ends in "carry on without a voice
/// note" rather than an error the client has to clear.
///
/// The transcript, not the audio, is the payload. It is handed up through
/// [onTranscriptChanged] as soon as recording stops, so "Analyse & Generate
/// Case" can send it with the documents and the pipeline never has to wait for
/// server-side transcription.
///
/// Rebuild discipline matches `VoiceRecorderButton`: the waveform, the elapsed
/// timer and the live text each sit behind their own [ValueNotifier], so
/// samples arriving ten times a second repaint a handful of bars rather than
/// the intake screen.
class VoiceNoteRecorder extends StatefulWidget {
  /// Called whenever the transcript changes in a way the case should carry:
  /// recording finished, the client edited it, or it was deleted.
  final ValueChanged<String> onTranscriptChanged;

  /// Called with the recorded audio file, or null when there is none.
  ///
  /// Only ever non-null on the record-only fallback path, or when
  /// [captureAudio] is on.
  final ValueChanged<File?> onAudioChanged;

  /// Reports listening state so the host can, for example, warn before
  /// navigating away.
  final ValueChanged<bool>? onListeningChanged;

  /// Locale ids to prefer for recognition, best first — normally the app's
  /// current language followed by English.
  ///
  /// Null means "use the configured list"; see [effectivePreferredLocales].
  final List<String>? preferredLocales;

  /// The locales actually used: the caller's override, or
  /// SPEECH_PREFERRED_LOCALES from .env.
  List<String> get effectivePreferredLocales =>
      preferredLocales ?? AppConfig.speechPreferredLocales;

  /// Hard cap on one recording. Reaching it stops and finalises rather than
  /// letting a client produce a transcript nothing will accept.
  ///
  /// Null means "use the configured cap"; see [effectiveMaxDuration].
  final Duration? maxDuration;

  /// The cap actually applied: an explicit [maxDuration] if the caller set one,
  /// otherwise VOICE_NOTE_MAX_DURATION_MINUTES from .env.
  Duration get effectiveMaxDuration =>
      maxDuration ?? AppConfig.voiceNoteMaxDuration;

  /// Whether to also capture the raw audio while live transcription runs.
  ///
  /// Off by default, and that is deliberate. Android and iOS both give the
  /// microphone to one capture client at a time: with the recogniser holding
  /// it, a parallel `MediaRecorder`/`AVAudioRecorder` either fails to start or
  /// records silence on most devices. Since the live transcript is uploaded as
  /// text and the backend no longer needs audio to produce one, the trade is
  /// not worth a silent file on every submission. Turn it on if an engagement
  /// requires the original audio to be retained for validation — capture is
  /// best effort and its failure never affects the transcript.
  final bool captureAudio;

  /// Builds the recogniser wrapper. Exists so a test can drive this widget from
  /// a fake platform instead of the app-wide `SpeechToText` singleton, whose
  /// initialised state would otherwise leak between tests.
  @visibleForTesting
  final LiveTranscriptionService Function()? transcriptionServiceFactory;

  const VoiceNoteRecorder({
    super.key,
    required this.onTranscriptChanged,
    required this.onAudioChanged,
    this.onListeningChanged,
    this.preferredLocales,
    this.maxDuration,
    this.captureAudio = false,
    this.transcriptionServiceFactory,
  });

  @override
  State<VoiceNoteRecorder> createState() => _VoiceNoteRecorderState();
}

class _VoiceNoteRecorderState extends State<VoiceNoteRecorder>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final LiveTranscriptionService _live;
  final VoiceAudioCapture _audio = VoiceAudioCapture(filePrefix: 'voice_case');

  final TextEditingController _transcriptController = TextEditingController();

  /// Live text while listening. Kept out of [_transcriptController] so partial
  /// results cannot fight with the client's cursor once they start editing.
  final ValueNotifier<String> _liveText = ValueNotifier('');
  final ValueNotifier<List<double>> _levels = ValueNotifier(const []);
  final ValueNotifier<int> _elapsedSeconds = ValueNotifier(0);

  late final AnimationController _pulse;

  _Stage _stage = _Stage.idle;
  _Engine _engine = _Engine.live;
  bool _busy = false;

  /// Set while [stop] waits for the platform's trailing final result, so a late
  /// correction can still land — but only until the client touches the text.
  bool _awaitingFinal = false;
  bool _userEditedTranscript = false;

  /// The transcript the current session began with, which "Add more" seeds and
  /// Cancel restores. Empty for a fresh recording.
  String _seedAtStart = '';

  /// An interruption that arrived while another operation held [_busy].
  ///
  /// Dropping it would leave the microphone open with the UI stuck on
  /// "Listening…" — the exact case of a call landing in the moment between the
  /// mic button and the recogniser actually starting.
  String? _pendingStopMessage;

  String? _notice;
  bool _noticeIsError = true;

  File? _audioFile;
  Timer? _timer;
  StreamSubscription<Amplitude>? _amplitudeSub;

  /// Bars in the waveform, matching the shared recorder button's density.
  static const _barCount = 28;

  /// `record` reports dBFS; normal speech sits around -40..-10, so the floor is
  /// clamped there to give the bars visible movement.
  static const _minDb = -45.0;

  /// A transcript longer than this is past anything a client dictates and past
  /// what the extraction prompt can use; the backend applies the same ceiling.
  /// Configured as MAX_TRANSCRIPT_CHARS in .env.
  static int get _maxTranscriptChars => AppConfig.maxTranscriptChars;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Driven only while listening. Left repeating for the life of the screen it
    // would schedule a frame on every vsync forever, for an indicator that is
    // not even on screen.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _live = (widget.transcriptionServiceFactory ?? LiveTranscriptionService.new)()
      ..onTranscript = _onTranscript
      ..onSoundLevel = _pushLevel
      ..onFailure = _onFailure
      ..onListeningChanged = _onEngineListeningChanged;

    _transcriptController.addListener(_onTranscriptEdited);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _amplitudeSub?.cancel();
    _pulse.dispose();

    // Detach synchronously, before anything below is torn down. The service's
    // own dispose clears these too, but it awaits the platform first, and a
    // sound level arriving in that window would push into a disposed notifier.
    _live
      ..onTranscript = null
      ..onSoundLevel = null
      ..onListeningChanged = null
      ..onFailure = null;

    // Fire and forget: both release platform resources and neither can throw
    // into dispose. Ordering does not matter, only that both run.
    unawaited(_live.dispose());
    unawaited(_audio.dispose());

    _transcriptController.removeListener(_onTranscriptEdited);
    _transcriptController.dispose();
    _liveText.dispose();
    _levels.dispose();
    _elapsedSeconds.dispose();
    super.dispose();
  }

  /// Backgrounding takes the microphone away — an incoming call, a switch to
  /// another app, the screen locking. Finalise what was captured instead of
  /// leaving a session that will never produce another word.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_stage != _Stage.listening) return;
    if (state != AppLifecycleState.paused && state != AppLifecycleState.hidden) {
      return;
    }

    const message = 'Recording stopped because the app went to the background. '
        'Your transcript so far has been kept.';

    // Starting is not instantaneous — permission, initialise, listen. An
    // interruption inside that window is queued rather than dropped.
    if (_busy) {
      _pendingStopMessage = message;
      return;
    }

    unawaited(_stopRecording(interruptedMessage: message));
  }

  /// Runs a stop that arrived while [_busy] was held.
  void _drainPendingStop() {
    final message = _pendingStopMessage;
    if (message == null) return;
    _pendingStopMessage = null;
    if (_stage != _Stage.listening) return;
    unawaited(_stopRecording(interruptedMessage: message));
  }

  // ── engine callbacks ─────────────────────────────────────────────────────

  void _onTranscript(String text) {
    if (!mounted) return;

    if (_stage == _Stage.listening) {
      _liveText.value = text;
      return;
    }

    // A final result that arrived after Stop. Accept it only while the client
    // has not started editing, so a correction never overwrites their words.
    if (_awaitingFinal && !_userEditedTranscript && text.isNotEmpty) {
      _setTranscript(text);
    }
  }

  void _onEngineListeningChanged(bool listening) {
    if (!mounted) return;
    widget.onListeningChanged?.call(listening);
  }

  void _onFailure(VoiceTranscriptionFailure failure) {
    if (!mounted) return;

    // The recogniser is missing or unusable on this device, but the microphone
    // itself works. Drop to record-and-transcribe-server-side rather than
    // denying the client a voice note.
    if (failure.fault == VoiceTranscriptionFault.unavailable &&
        _stage != _Stage.review) {
      unawaited(_startAudioOnly(reason: failure.message));
      return;
    }

    _finaliseAfterFailure(failure.message);
  }

  // ── recording lifecycle ──────────────────────────────────────────────────

  Future<void> _start({bool append = false}) async {
    if (_busy) return;
    _busy = true;

    // An interruption queued against a session that has since ended — cancelled
    // or stopped while it was still starting — must not be drained into this
    // one, which would stop a fresh recording the instant it began.
    _pendingStopMessage = null;

    try {
      final seed = append ? _transcriptController.text.trim() : '';
      _seedAtStart = seed;

      if (!append) {
        _transcriptController.value = TextEditingValue.empty;
      }

      // Any audio already held stops matching the transcript the moment more
      // speech is added to it, so it goes either way. Re-recording starts from
      // nothing; appending keeps the transcript and drops the stale recording.
      await _discardAudio();

      setState(() {
        _notice = null;
        _engine = _Engine.live;
        _stage = _Stage.listening;
        _userEditedTranscript = false;
        _awaitingFinal = false;
      });

      _liveText.value = seed;
      _levels.value = const [];
      _elapsedSeconds.value = 0;
      unawaited(_pulse.repeat(reverse: true));

      final started = await _live.start(
        preferredLocales: widget.effectivePreferredLocales,
        seed: seed,
      );

      if (!mounted) return;

      // _onFailure has already routed to the fallback or shown a message; do
      // not undo whatever it decided.
      if (!started) {
        if (_stage == _Stage.listening && _engine == _Engine.live) {
          _pulse.stop();
          setState(() => _stage = seed.isEmpty ? _Stage.idle : _Stage.review);
        }
        return;
      }

      // Optional, best effort, and never allowed to affect the transcript.
      if (widget.captureAudio && !append) {
        final captured = await _audio.start();
        if (!captured) {
          debugPrint('Voice note: audio capture unavailable alongside recognition.');
        }
      }

      _startTimer();
    } finally {
      _busy = false;
      _drainPendingStop();
    }
  }

  /// The device has no usable speech recogniser: record audio and let the
  /// backend transcribe it, which is the behaviour this feature shipped with.
  Future<void> _startAudioOnly({required String reason}) async {
    final started = await _audio.start();

    if (!mounted) return;

    if (!started) {
      _finaliseAfterFailure(
        'The microphone is not available. Please check the app\'s microphone '
        'permission and try again.',
      );
      return;
    }

    setState(() {
      _engine = _Engine.audioOnly;
      _stage = _Stage.listening;
      _notice = reason;
      _noticeIsError = false;
    });

    _liveText.value = '';
    _levels.value = const [];
    _elapsedSeconds.value = 0;

    _amplitudeSub = _audio.amplitudes().listen(
          (amp) => _pushLevel(_normaliseDb(amp.current)),
          onError: (Object e) => debugPrint('Amplitude stream failed: $e'),
        );

    _startTimer();
    widget.onListeningChanged?.call(true);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds.value++;
      if (_elapsedSeconds.value >= widget.effectiveMaxDuration.inSeconds) {
        unawaited(_stopRecording(
          interruptedMessage:
              'Recording reached the ${widget.effectiveMaxDuration.inMinutes}-minute limit and was saved.',
        ));
      }
    });
  }

  /// Ends recording and moves straight to the editable transcript.
  ///
  /// Nothing here waits on the network or on the platform: the text already on
  /// screen becomes the transcript immediately, and the trailing final result —
  /// if the recogniser sends one — is merged in behind the client.
  Future<void> _stopRecording({String? interruptedMessage}) async {
    if (_busy || _stage != _Stage.listening) return;
    _busy = true;

    _pulse.stop();
    _timer?.cancel();
    _timer = null;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;

    try {
      if (_engine == _Engine.audioOnly) {
        final file = await _audio.stop();
        if (!mounted) return;

        if (file == null) {
          setState(() {
            _stage = _Stage.idle;
            _notice = 'That recording was too short. Please try again.';
            _noticeIsError = true;
          });
          widget.onListeningChanged?.call(false);
          return;
        }

        _setAudio(file);
        setState(() {
          _stage = _Stage.review;
          if (interruptedMessage != null) {
            _notice = interruptedMessage;
            _noticeIsError = false;
          }
        });
        widget.onListeningChanged?.call(false);
        return;
      }

      // Live engine: show what we have now, reconcile the final result after.
      final immediate = _live.transcript.trim();

      setState(() {
        _stage = immediate.isEmpty ? _Stage.idle : _Stage.review;
        _awaitingFinal = true;
        if (interruptedMessage != null) {
          _notice = interruptedMessage;
          _noticeIsError = false;
        }
      });

      if (immediate.isNotEmpty) _setTranscript(immediate);

      final settled = (await _live.stop()).trim();
      final captured = await _audio.stop();
      if (captured != null) _setAudio(captured);

      if (!mounted) return;

      _awaitingFinal = false;

      if (settled.isEmpty) {
        setState(() {
          _stage = _Stage.idle;
          if (interruptedMessage == null) {
            _notice = 'We did not catch anything. Please try again and speak clearly.';
            _noticeIsError = true;
          }
        });
        widget.onListeningChanged?.call(false);
        return;
      }

      if (!_userEditedTranscript && settled != _transcriptController.text.trim()) {
        _setTranscript(settled);
      }

      setState(() => _stage = _Stage.review);
    } catch (e) {
      debugPrint('Voice note stop failed: $e');
      if (mounted) {
        setState(() {
          _stage = _transcriptController.text.trim().isEmpty
              ? _Stage.idle
              : _Stage.review;
          _notice = 'Recording could not be finished cleanly. '
              'Anything already transcribed has been kept.';
          _noticeIsError = true;
        });
      }
    } finally {
      _busy = false;
      if (mounted) widget.onListeningChanged?.call(false);
    }
  }

  /// Abandons the recording in progress and everything it produced.
  ///
  /// Cancelling an "add more" session abandons only the addition: the
  /// transcript the client already had comes back untouched. Leaving it out
  /// dropped the UI to its empty state while that earlier text was still held
  /// in the provider, so a case was submitted with a voice note the screen
  /// said did not exist.
  Future<void> _cancelRecording() async {
    if (_busy) return;
    _busy = true;

    _pulse.stop();
    _timer?.cancel();
    _timer = null;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;

    try {
      await _live.cancel();
      await _audio.stop(discard: true);
    } catch (e) {
      debugPrint('Voice note cancel failed: $e');
    } finally {
      _busy = false;
    }

    if (!mounted) return;

    final restored = _seedAtStart;
    _liveText.value = '';

    if (restored.isEmpty) {
      // A fresh recording: _start already emptied the controller, which pushed
      // the cleared transcript up.
      _transcriptController.value = TextEditingValue.empty;
    } else {
      _setTranscript(restored);
    }

    setState(() {
      _stage = restored.isEmpty ? _Stage.idle : _Stage.review;
      _awaitingFinal = false;
      _notice = null;
    });
    widget.onListeningChanged?.call(false);
  }

  /// Drops the transcript and the audio, returning to the untouched state.
  Future<void> _delete() async {
    _transcriptController.value = TextEditingValue.empty;
    _liveText.value = '';
    _userEditedTranscript = false;
    await _discardAudio();

    widget.onTranscriptChanged('');

    if (!mounted) return;
    setState(() {
      _stage = _Stage.idle;
      _notice = null;
    });
  }

  Future<void> _discardAudio() async {
    final file = _audioFile;
    _audioFile = null;
    if (file != null) {
      widget.onAudioChanged(null);
      await _audio.deleteFile(file);
    }
  }

  void _finaliseAfterFailure(String message) {
    _pulse.stop();
    _timer?.cancel();
    _timer = null;
    unawaited(_amplitudeSub?.cancel());
    _amplitudeSub = null;

    final kept = _live.transcript.trim();
    if (kept.isNotEmpty && !_userEditedTranscript) _setTranscript(kept);

    if (!mounted) return;
    setState(() {
      _stage = _transcriptController.text.trim().isEmpty ? _Stage.idle : _Stage.review;
      _notice = message;
      _noticeIsError = true;
      _awaitingFinal = false;
    });
    widget.onListeningChanged?.call(false);
  }

  // ── transcript plumbing ──────────────────────────────────────────────────

  void _setTranscript(String text) {
    final capped = text.length > _maxTranscriptChars
        ? text.substring(0, _maxTranscriptChars)
        : text;

    // Assigning `text` alone would move the cursor; this keeps it at the end,
    // which is where a client continuing to dictate expects it.
    _transcriptController.value = TextEditingValue(
      text: capped,
      selection: TextSelection.collapsed(offset: capped.length),
    );
  }

  void _onTranscriptEdited() {
    if (_stage == _Stage.review && !_awaitingFinal) _userEditedTranscript = true;
    widget.onTranscriptChanged(_transcriptController.text.trim());
  }

  void _setAudio(File file) {
    _audioFile = file;
    widget.onAudioChanged(file);
  }

  void _pushLevel(double level) {
    final next = List<double>.of(_levels.value)..add(level.clamp(0.0, 1.0));
    if (next.length > _barCount) next.removeAt(0);
    _levels.value = next;
  }

  double _normaliseDb(double db) {
    if (db.isNaN || db.isInfinite) return 0;
    final clamped = db.clamp(_minDb, 0.0);
    return (clamped - _minDb) / -_minDb;
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.aiCardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _stage == _Stage.listening
                  ? AppColors.error.withValues(alpha: 0.55)
                  : AppColors.primaryText.withValues(alpha: 0.12),
            ),
          ),
          child: switch (_stage) {
            _Stage.idle => _buildIdle(),
            _Stage.listening => _buildListening(),
            _Stage.review => _buildReview(),
          },
        ),
        if (_notice != null) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _noticeIsError ? Icons.error_outline : Icons.info_outline,
                size: 15,
                color: _noticeIsError ? AppColors.error : AppColors.mutedText,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _notice!,
                  style: TextStyle(
                    color: _noticeIsError ? AppColors.error : AppColors.mutedText,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildIdle() {
    return Row(
      children: [
        _MicButton(onTap: () => _start(), busy: _busy),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tap mic and start speaking',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Your words appear as you speak — you can edit them before submitting.',
                style: TextStyle(color: AppColors.mutedText, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListening() {
    final isLive = _engine == _Engine.live;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FadeTransition(
              opacity: _pulse.drive(Tween(begin: 0.35, end: 1.0)),
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.error,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isLive ? 'Listening…' : 'Recording…',
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
              ),
            ),
            const Spacer(),
            ValueListenableBuilder<int>(
              valueListenable: _elapsedSeconds,
              builder: (_, seconds, _) => Text(
                '${_formatDuration(seconds)} / ${_formatDuration(widget.effectiveMaxDuration.inSeconds)}',
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 11.5,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Only these bars repaint on each microphone sample.
        Center(
          child: ValueListenableBuilder<List<double>>(
            valueListenable: _levels,
            builder: (_, levels, _) =>
                _Waveform(levels: levels, barCount: _barCount),
          ),
        ),
        const SizedBox(height: 12),

        if (isLive)
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 64, maxHeight: 180),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.aiCardBackgroundAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ValueListenableBuilder<String>(
              valueListenable: _liveText,
              builder: (_, text, _) {
                if (text.isEmpty) {
                  return const Text(
                    'Start speaking — your words will appear here.',
                    style: TextStyle(color: AppColors.mutedText, fontSize: 12.5),
                  );
                }
                return SingleChildScrollView(
                  reverse: true,
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                );
              },
            ),
          )
        else
          const Text(
            'Live transcription is unavailable, so this note will be transcribed '
            'after you submit. Speak clearly into your phone.',
            style: TextStyle(color: AppColors.mutedText, fontSize: 12),
          ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _cancelRecording,
                icon: const Icon(Icons.close, size: 16),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.mutedText,
                  side: BorderSide(
                    color: AppColors.primaryText.withValues(alpha: 0.2),
                  ),
                ),
                label: const Text('Cancel', style: TextStyle(fontSize: 13)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _busy ? null : () => _stopRecording(),
                icon: const Icon(Icons.stop_rounded, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.primaryText,
                ),
                label: const Text('Stop', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReview() {
    final isLive = _engine == _Engine.live;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isLive ? 'Voice note transcribed' : 'Voice note recorded',
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: _elapsedSeconds,
              builder: (_, seconds, _) => Text(
                _formatDuration(seconds),
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 11.5,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (isLive) ...[
          TextField(
            controller: _transcriptController,
            maxLines: 6,
            minLines: 3,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 13,
              height: 1.45,
            ),
            decoration: InputDecoration(
              hintText: 'Your transcript appears here — edit it if needed.',
              hintStyle: TextStyle(
                color: AppColors.primaryText.withValues(alpha: 0.38),
                fontSize: 12,
              ),
              filled: true,
              fillColor: AppColors.aiCardBackgroundAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.primaryText.withValues(alpha: 0.12),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryGold),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Kept on this device until you submit the case.',
            style: TextStyle(color: AppColors.mutedText, fontSize: 11),
          ),
        ] else
          const Text(
            'This note will be transcribed when you submit the case.',
            style: TextStyle(color: AppColors.mutedText, fontSize: 12),
          ),
        const SizedBox(height: 12),

        Row(
          children: [
            if (isLive) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _start(append: true),
                  icon: const Icon(Icons.mic_none_rounded, size: 16),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGold,
                    side: BorderSide(
                      color: AppColors.primaryGold.withValues(alpha: 0.6),
                    ),
                  ),
                  label: const Text('Add more', style: TextStyle(fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _start(),
                icon: const Icon(Icons.refresh, size: 16),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryText,
                  side: BorderSide(
                    color: AppColors.primaryText.withValues(alpha: 0.2),
                  ),
                ),
                label: const Text('Re-record', style: TextStyle(fontSize: 12.5)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline, size: 16),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                ),
                label: const Text('Delete', style: TextStyle(fontSize: 12.5)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MicButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool busy;

  const _MicButton({required this.onTap, required this.busy});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Record a voice note',
      child: Tooltip(
        message: 'Record a voice note',
        child: InkWell(
          onTap: busy ? null : onTap,
          customBorder: const CircleBorder(),
          // 48dp keeps the tap target at the platform minimum even though the
          // painted circle is smaller.
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryGold,
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: AppColors.onGold,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Live level meter. Stateless and private so a rebuild costs nothing.
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
      height: 32,
      width: barCount * 6.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final level in padded.take(barCount))
            Container(
              width: 3,
              height: 4 + (level * 28),
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: AppColors.primaryGold,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}
