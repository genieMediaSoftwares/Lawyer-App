import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../models/ai_smart_case_models.dart';
import '../repositories/ai_smart_case_repository.dart';
import '../utils/ai_smart_case_logger.dart';

final aiSmartCaseRepositoryProvider = Provider<AISmartCaseRepository>((ref) {
  return AISmartCaseRepository();
});

/// State for the document-intake step.
///
/// Extraction hands its result to the Post Case form, which owns everything
/// from that point on — there is no separate questions, review or lawyer
/// screen in this feature.
class AISmartCaseState {
  /// Picked documents, held as [PlatformFile] rather than `dart:io` `File`.
  ///
  /// `File` is not implemented on Flutter web — constructing one throws
  /// `Unsupported operation: _Namespace`. file_picker's web backend returns a
  /// `blob:` URL in `PlatformFile.path` (not null), so a `path != null` guard
  /// does not protect you.
  final List<PlatformFile> selectedFiles;

  /// The original audio, when there is any.
  ///
  /// Optional now that the device transcribes while the client speaks: it is
  /// only present on devices with no speech recogniser, where the backend
  /// still does the transcription, or when audio retention is switched on.
  final File? voiceFile;

  /// What the client said, transcribed on the device and editable by them.
  ///
  /// Sent with the documents so extraction can use it straight away rather
  /// than waiting on server-side transcription.
  final String voiceTranscript;

  /// The client's typed notes, kept separate from [voiceTranscript] so the two
  /// reach the pipeline as distinct inputs.
  final String writtenNotes;

  final bool isRecording;
  final bool isExtracting;

  /// The id of the run in flight, so the screen can resubscribe after a
  /// rebuild instead of starting a second analysis.
  final String? sessionId;

  /// The latest position reported by the backend. Never advanced locally,
  /// except during `uploading`, where the only thing that can measure progress
  /// is the device doing the sending.
  final AnalysisProgress progress;

  final ExtractionResult? result;
  final String? errorMessage;

  /// How many times this intake has been retried. Surfaced so the screen can
  /// stop offering an endless retry loop against a permanently failing input.
  final int attempt;

  const AISmartCaseState({
    this.selectedFiles = const [],
    this.voiceFile,
    this.voiceTranscript = '',
    this.writtenNotes = '',
    this.isRecording = false,
    this.isExtracting = false,
    this.sessionId,
    this.progress = const AnalysisProgress(),
    this.result,
    this.errorMessage,
    this.attempt = 0,
  });

  /// True when a run has produced a result the Post Case form can be opened
  /// with. Reading `result != null` directly is the same test; this names the
  /// intent at the call sites that decide whether to navigate.
  bool get hasResult => result != null;

  /// Nullable fields use explicit sentinel flags rather than `x ?? this.x`.
  ///
  /// With the `??` form, passing null meant "leave unchanged", so
  /// `setVoiceFile(null)` silently did nothing — there was no way to remove a
  /// recording.
  ///
  /// [result] and [sessionId] were left on the `??` form and had the same
  /// defect with worse consequences: starting a second analysis passed
  /// `result: null` to clear the previous document's extraction and it was
  /// discarded, so the first document's data survived into the second run.
  ///
  /// [errorMessage] is the mirror image: it used to be assigned unconditionally,
  /// so *any* `copyWith` that did not mention it wiped the error. A progress
  /// event arriving from the poll a moment after a failure therefore cleared
  /// the message the screen was showing, and the run looked like it was still
  /// running. It now needs [clearError] to be cleared, like every other
  /// nullable field here.
  AISmartCaseState copyWith({
    List<PlatformFile>? selectedFiles,
    File? voiceFile,
    bool clearVoiceFile = false,
    String? voiceTranscript,
    String? writtenNotes,
    bool? isRecording,
    bool? isExtracting,
    String? sessionId,
    bool clearSessionId = false,
    AnalysisProgress? progress,
    ExtractionResult? result,
    bool clearResult = false,
    String? errorMessage,
    bool clearError = false,
    int? attempt,
  }) {
    return AISmartCaseState(
      selectedFiles: selectedFiles ?? this.selectedFiles,
      voiceFile: clearVoiceFile ? null : (voiceFile ?? this.voiceFile),
      voiceTranscript: voiceTranscript ?? this.voiceTranscript,
      writtenNotes: writtenNotes ?? this.writtenNotes,
      isRecording: isRecording ?? this.isRecording,
      isExtracting: isExtracting ?? this.isExtracting,
      sessionId: clearSessionId ? null : (sessionId ?? this.sessionId),
      progress: progress ?? this.progress,
      result: clearResult ? null : (result ?? this.result),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      attempt: attempt ?? this.attempt,
    );
  }
}

class AISmartCaseNotifier extends StateNotifier<AISmartCaseState> {
  AISmartCaseNotifier(this._repository) : super(const AISmartCaseState());

  final AISmartCaseRepository _repository;

  /// The live subscription to the backend pipeline, or null between runs.
  StreamSubscription<AnalysisEvent>? _subscription;

  /// Completes when the run in flight settles. Held so that a second caller —
  /// the processing screen rebuilding, a retry press, a route re-entry —
  /// *joins* the run in progress instead of starting a competing one.
  Completer<bool>? _inFlight;

  /// Cancels the upload if the run is abandoned mid-send.
  CancelToken? _uploadCancelToken;

  /// Idempotency key for the current intake, reused across upload retries so
  /// the server returns the same session rather than analysing the documents a
  /// second time.
  String? _requestId;

  /// Guards against a stale run writing state after a newer one started. Each
  /// run captures this value; a callback whose token no longer matches is from
  /// an abandoned run and is dropped.
  int _runToken = 0;

  /// Upload attempts per run, for transient network failures only.
  /// Configured as AI_REQUEST_MAX_RETRIES in .env.
  static int get _maxUploadAttempts => AppConfig.aiRequestMaxRetries;

  /// Absolute ceiling on one end-to-end run, as a last line of defence. The
  /// repository's watch has its own timeouts; this covers the window before a
  /// watch even exists, so `startExtraction` can never return a future that
  /// nothing completes. Configured as AI_RUN_TIMEOUT_MINUTES in .env.
  static Duration get _runTimeout => AppConfig.aiRunTimeout;

  @override
  void dispose() {
    _teardownRun('notifier disposed');
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Intake inputs
  // ───────────────────────────────────────────────────────────────────────────

  /// An extraction describes the exact inputs that produced it, so any change
  /// to those inputs invalidates it.
  ///
  /// This is what makes it safe for [startExtraction] to hand back an existing
  /// result instead of re-uploading: the only way to still be holding one is to
  /// have changed nothing since. Without it, adding a second document and
  /// pressing Analyse returned the *first* document's extraction — the original
  /// "uploaded a different document, got the old data" report, reintroduced by
  /// the reuse path rather than by `copyWith`.
  void _invalidateResult() {
    if (!state.hasResult && state.sessionId == null) return;
    state = state.copyWith(clearResult: true, clearSessionId: true);
  }

  void addFiles(List<PlatformFile> newFiles) {
    if (newFiles.isEmpty) return;
    _invalidateResult();
    final updated = List<PlatformFile>.from(state.selectedFiles)..addAll(newFiles);
    state = state.copyWith(selectedFiles: updated, clearError: true);
  }

  void removeFile(PlatformFile file) {
    _invalidateResult();
    final updated = List<PlatformFile>.from(state.selectedFiles)..remove(file);
    state = state.copyWith(selectedFiles: updated, clearError: true);
  }

  /// Replaces the voice note, deleting the file it supersedes.
  ///
  /// Each recording writes a new file into the temp directory. Without this,
  /// re-recording several times left every previous take on disk for the OS to
  /// reclaim whenever it felt like it — on a device short on space that is the
  /// difference between the next recording working and failing.
  void setVoiceFile(File? file) {
    final previous = state.voiceFile;
    if (previous != null && previous.path != file?.path) {
      unawaited(_deleteQuietly(previous));
    }
    _invalidateResult();
    state = state.copyWith(voiceFile: file, clearVoiceFile: file == null);
  }

  void setVoiceTranscript(String text) {
    final trimmed = text.trim();
    if (trimmed == state.voiceTranscript) return;
    _invalidateResult();
    state = state.copyWith(voiceTranscript: trimmed);
  }

  void setWrittenNotes(String text) {
    state = state.copyWith(writtenNotes: text);
  }

  void setRecordingState(bool recording) {
    state = state.copyWith(isRecording: recording);
  }

  /// Clears the error banner without touching anything else, so editing the
  /// selection after a failure removes the stale message.
  void clearError() {
    if (state.errorMessage == null) return;
    state = state.copyWith(clearError: true);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ───────────────────────────────────────────────────────────────────────────

  /// Clears everything, including any run in flight.
  ///
  /// Called when the intake screen is opened. Without it the screen came back
  /// still holding the previous run's files, voice note and result, and a
  /// second analysis re-uploaded the first run's documents alongside the new
  /// ones.
  void reset() {
    _teardownRun('reset');
    state = const AISmartCaseState();
  }

  /// Drops the previous run's inputs and output, ready for a new document.
  ///
  /// Called when the intake screen is shown again after handing a result to the
  /// Post Case form. [reset] cannot be used there: it also clears [progress],
  /// and the processing screen is still animating out at that moment, so its
  /// timeline would visibly snap back to the first stage on the way off screen.
  ///
  /// Without this, returning to intake kept the previous document selected, and
  /// picking a second one *appended* to it — so "upload a different document"
  /// re-uploaded the first one alongside it and analysed both.
  void clearForNewIntake() {
    _teardownRun('new intake');
    state = state.copyWith(
      selectedFiles: const [],
      clearVoiceFile: true,
      voiceTranscript: '',
      writtenNotes: '',
      isRecording: false,
      isExtracting: false,
      clearResult: true,
      clearSessionId: true,
      clearError: true,
      attempt: 0,
    );
  }

  /// Abandons the run in flight without discarding the client's inputs, so the
  /// intake screen still has the documents if they come back and retry.
  ///
  /// Called when the processing screen is left before the analysis finished.
  /// The server-side run continues — it is detached by design and its result is
  /// still retrievable by session id — but this device stops paying for a
  /// socket and a poll it is no longer showing anywhere.
  void cancelRun() {
    if (!state.isExtracting) return;
    _teardownRun('user left the processing screen');
    if (!mounted) return;
    state = state.copyWith(isExtracting: false);
  }

  /// Releases everything one run owns and invalidates its callbacks.
  void _teardownRun(String reason) {
    _runToken += 1;

    final pending = _inFlight;
    _inFlight = null;
    if (pending != null && !pending.isCompleted) pending.complete(false);

    _subscription?.cancel();
    _subscription = null;

    if (_uploadCancelToken?.isCancelled == false) {
      _uploadCancelToken!.cancel('AI intake $reason');
    }
    _uploadCancelToken = null;

    _requestId = null;

    AILog.info('run:teardown', reason);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // The run
  // ───────────────────────────────────────────────────────────────────────────

  /// Uploads the intake and follows the backend pipeline to completion.
  ///
  /// Returns true when there is a result to pre-fill the Post Case form with.
  /// Progress reaches the UI only through backend events — there is no timer
  /// and no simulated advancement anywhere after the upload finishes.
  ///
  /// Safe to call concurrently: a second call while a run is in flight *joins*
  /// that run and resolves with its outcome. That is what makes a rebuild of
  /// the processing screen, or a double tap on Retry, harmless — both used to
  /// either start a duplicate upload or return false immediately and leave the
  /// screen showing a spinner nothing would ever finish.
  Future<bool> startExtraction() async {
    // Already finished successfully and not yet cleared: hand back the same
    // result rather than re-analysing documents we already have an answer for.
    if (!state.isExtracting && state.hasResult) {
      AILog.info('run:reusing-existing-result');
      return true;
    }

    final joined = _inFlight;
    if (joined != null && !joined.isCompleted) {
      AILog.info('run:joined-in-flight');
      return joined.future;
    }

    if (state.selectedFiles.isEmpty) {
      state = state.copyWith(
        isExtracting: false,
        errorMessage:
            'Please upload at least one document. A voice note or written notes can add extra detail.',
      );
      return false;
    }

    // Claim the run and wipe the previous one *synchronously*, before the first
    // await, so a second press in the same frame sees the claim. Every run
    // starts from nothing: no previous extraction, no previous session id, no
    // stale error.
    final completer = Completer<bool>();
    _inFlight = completer;
    _runToken += 1;
    final token = _runToken;
    _requestId = _newRequestId();

    state = state.copyWith(
      isExtracting: true,
      progress: const AnalysisProgress(
        stage: 'uploading',
        message: 'Uploading your documents…',
      ),
      clearResult: true,
      clearSessionId: true,
      clearError: true,
      attempt: state.attempt + 1,
    );

    // Abandon anything still streaming from the previous run before its events
    // can be mistaken for this one's.
    await _subscription?.cancel();
    _subscription = null;

    unawaited(_execute(token, completer));

    // The future is completed by the stream callbacks below, by a transport
    // failure, or by this timeout. There is no path on which it hangs.
    return completer.future.timeout(
      _runTimeout,
      onTimeout: () {
        AILog.warn('run:timeout');
        _settle(
          token,
          completer,
          success: false,
          error: 'The analysis took too long and was stopped. '
              'Please try again with fewer or smaller documents.',
        );
        return false;
      },
    );
  }

  /// Upload, then subscribe. Split out so [startExtraction] can claim the run
  /// synchronously and still return a future that is always completed.
  Future<void> _execute(int token, Completer<bool> completer) async {
    try {
      final sessionId = await _uploadWithRetry(token);
      if (token != _runToken || !mounted) return;

      AILog.session = sessionId;
      state = state.copyWith(
        sessionId: sessionId,
        progress: const AnalysisProgress(
          stage: 'queued',
          message: 'Preparing your documents…',
          percent: 2,
        ),
      );

      _subscription = _repository.watch(sessionId).listen(
        (event) {
          if (token != _runToken || !mounted) return;

          if (event.progress != null) {
            // A progress event arriving after the run already settled would
            // reopen a finished screen. The stream closes on completion, but a
            // packet already in flight can still land first.
            if (completer.isCompleted) return;
            state = state.copyWith(progress: event.progress);
            return;
          }

          if (event.result != null) {
            state = state.copyWith(
              progress: const AnalysisProgress(
                stage: 'completed',
                message: 'Analysis complete',
                percent: 100,
              ),
              result: event.result,
            );
            _settle(token, completer, success: true);
            return;
          }

          if (event.error != null) {
            _settle(token, completer, success: false, error: event.error);
          }
        },
        onError: (Object e, StackTrace s) {
          AILog.error('watch:stream-error', e, s);
          _settle(token, completer, success: false, error: _friendlyError(e));
        },
        onDone: () {
          if (completer.isCompleted) return;

          // Reaching here means the stream closed without delivering a result
          // for *this* run. Reading `state.result` to decide would report
          // success off whatever the previous document left behind, which is
          // how a failed second analysis used to open the form pre-filled with
          // the first document's details.
          _settle(
            token,
            completer,
            success: false,
            error: 'The analysis finished without returning any details. Please try again.',
          );
        },
        cancelOnError: false,
      );
    } on AnalysisInputException catch (e) {
      AILog.warn('upload:rejected-input', e.message);
      _settle(token, completer, success: false, error: e.message);
    } catch (e, s) {
      AILog.error('upload:failed', e, s);
      _settle(token, completer, success: false, error: _friendlyError(e));
    }
  }

  /// Uploads, retrying only failures that could not have reached the server or
  /// that the server itself asked us to retry.
  ///
  /// Safe because every attempt carries the same idempotency key — as a
  /// `requestId` form field, and additionally as the `X-Request-Id` header off
  /// the web. If an earlier attempt did land and only its response was lost,
  /// the server returns that same session instead of starting a second
  /// analysis of the same documents.
  Future<String> _uploadWithRetry(int token) async {
    Object? lastError;

    for (var attempt = 1; attempt <= _maxUploadAttempts; attempt++) {
      if (token != _runToken) {
        throw const AnalysisInputException('This analysis was cancelled.');
      }

      final cancelToken = CancelToken();
      _uploadCancelToken = cancelToken;

      try {
        return await _repository.startAnalysis(
          files: state.selectedFiles,
          voiceFile: state.voiceFile,
          voiceTranscript: state.voiceTranscript,
          issueDescription: state.writtenNotes,
          requestId: _requestId!,
          cancelToken: cancelToken,
          onProgress: (sent, total) => _onUploadProgress(token, sent, total),
        );
      } on AnalysisInputException {
        // A file that cannot be read will not become readable on a retry.
        rethrow;
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) {
          throw const AnalysisInputException('This analysis was cancelled.');
        }

        lastError = e;
        if (!_isRetryableUpload(e) || attempt == _maxUploadAttempts) rethrow;

        final backoff = AppConfig.aiRetryBaseDelay * attempt;
        final maxBackoff = AppConfig.aiRetryMaxDelay;
        final delay = backoff > maxBackoff ? maxBackoff : backoff;
        AILog.warn('upload:retry', 'attempt $attempt failed (${e.type}), waiting ${delay.inSeconds}s');

        if (mounted && token == _runToken) {
          state = state.copyWith(
            progress: AnalysisProgress(
              stage: 'uploading',
              message: 'Upload interrupted — retrying (${attempt + 1} of $_maxUploadAttempts)…',
              percent: state.progress.percent,
            ),
          );
        }
        await Future<void>.delayed(delay);
      }
    }

    throw lastError ?? Exception('Could not upload your documents. Please try again.');
  }

  /// Only failures that are plausibly transient. A 4xx is the server telling us
  /// the request itself is wrong, and resending it changes nothing.
  static bool _isRetryableUpload(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        // 408 Request Timeout and 5xx (except 501) are worth another attempt.
        return status == 408 || status == 429 || (status >= 500 && status != 501);
      default:
        return e.error is SocketException;
    }
  }

  /// Turns byte counts into the `uploading` stage's percentage.
  ///
  /// Capped at 15% of the overall bar, which is where the server's own
  /// `queued` stage picks up. Without this the bar reached 100% while the
  /// documents were merely *sent*, then sat there for the entire analysis.
  void _onUploadProgress(int token, int sent, int total) {
    if (token != _runToken || !mounted) return;
    if (total <= 0) return;

    final percent = ((sent / total) * 15).clamp(0, 15).round();
    if (percent == state.progress.percent && state.progress.stage == 'uploading') return;

    state = state.copyWith(
      progress: AnalysisProgress(
        stage: 'uploading',
        message: sent >= total
            ? 'Upload complete — starting analysis…'
            : 'Uploading your documents… ${_formatBytes(sent)} of ${_formatBytes(total)}',
        percent: percent,
      ),
    );
  }

  /// Single exit point for a run: completes the future exactly once, releases
  /// the run's resources, and writes the terminal state.
  ///
  /// Centralising this is what removed the class of bug where one path set
  /// `isExtracting: false` but left the subscription running, or completed the
  /// future without updating the screen.
  void _settle(
    int token,
    Completer<bool> completer, {
    required bool success,
    String? error,
  }) {
    if (token != _runToken) return;

    if (mounted) {
      state = state.copyWith(
        isExtracting: false,
        errorMessage: error,
        clearError: error == null,
      );
    }

    _subscription?.cancel();
    _subscription = null;
    _uploadCancelToken = null;

    if (_inFlight == completer) _inFlight = null;
    if (!completer.isCompleted) completer.complete(success);

    AILog.info('run:settled', success ? 'success' : 'failed: $error');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Helpers
  // ───────────────────────────────────────────────────────────────────────────

  /// Unique per intake. Timestamp plus randomness is enough: the server scopes
  /// the key to the authenticated client, so it only has to be unique per user.
  static String _newRequestId() {
    final random = math.Random();
    final suffix = List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join();
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-$suffix';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (e) {
      AILog.debug('voice:delete-failed', e);
    }
  }

  /// Turns transport failures into something a client can act on.
  String _friendlyError(Object e) {
    if (e is AnalysisInputException) return e.message;

    if (e is DioException) {
      if (CancelToken.isCancel(e)) return 'This analysis was cancelled.';

      switch (e.type) {
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.connectionTimeout:
          return 'Uploading your documents took too long. '
              'Please check your connection and try again.';
        case DioExceptionType.connectionError:
          return 'Could not reach the server. Please check your connection.';
        default:
          final data = e.response?.data;
          final message = data is Map ? data['message'] : null;
          if (message is String && message.isNotEmpty) return message;

          final status = e.response?.statusCode;
          if (status == 401 || status == 403) {
            return 'Your session expired. Please sign in again.';
          }
          if (status == 413) {
            return 'Those documents are too large to upload. '
                'Please remove the largest ones and try again.';
          }
          if (status == 429) {
            return 'You have a few analyses running already. '
                'Please wait for them to finish and try again.';
          }
          return 'Something went wrong while uploading your documents. Please try again.';
      }
    }

    return e.toString().replaceAll('Exception: ', '');
  }
}

final aiSmartCaseProvider =
    StateNotifierProvider<AISmartCaseNotifier, AISmartCaseState>((ref) {
  return AISmartCaseNotifier(ref.watch(aiSmartCaseRepositoryProvider));
});
