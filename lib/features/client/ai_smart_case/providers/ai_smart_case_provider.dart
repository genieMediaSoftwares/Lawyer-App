import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ai_smart_case_models.dart';
import '../repositories/ai_smart_case_repository.dart';

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

  final File? voiceFile;
  final String voiceTranscript;
  final bool isRecording;
  final bool isExtracting;

  /// The id of the run in flight, so the screen can resubscribe after a
  /// rebuild instead of starting a second analysis.
  final String? sessionId;

  /// The latest position reported by the backend. Never advanced locally.
  final AnalysisProgress progress;

  final ExtractionResult? result;
  final String? errorMessage;

  const AISmartCaseState({
    this.selectedFiles = const [],
    this.voiceFile,
    this.voiceTranscript = '',
    this.isRecording = false,
    this.isExtracting = false,
    this.sessionId,
    this.progress = const AnalysisProgress(),
    this.result,
    this.errorMessage,
  });

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
  AISmartCaseState copyWith({
    List<PlatformFile>? selectedFiles,
    File? voiceFile,
    bool clearVoiceFile = false,
    String? voiceTranscript,
    bool? isRecording,
    bool? isExtracting,
    String? sessionId,
    bool clearSessionId = false,
    AnalysisProgress? progress,
    ExtractionResult? result,
    bool clearResult = false,
    String? errorMessage,
  }) {
    return AISmartCaseState(
      selectedFiles: selectedFiles ?? this.selectedFiles,
      voiceFile: clearVoiceFile ? null : (voiceFile ?? this.voiceFile),
      voiceTranscript: voiceTranscript ?? this.voiceTranscript,
      isRecording: isRecording ?? this.isRecording,
      isExtracting: isExtracting ?? this.isExtracting,
      sessionId: clearSessionId ? null : (sessionId ?? this.sessionId),
      progress: progress ?? this.progress,
      result: clearResult ? null : (result ?? this.result),
      errorMessage: errorMessage,
    );
  }
}

class AISmartCaseNotifier extends StateNotifier<AISmartCaseState> {
  AISmartCaseNotifier(this._repository) : super(const AISmartCaseState());

  final AISmartCaseRepository _repository;

  StreamSubscription<AnalysisEvent>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void addFiles(List<PlatformFile> newFiles) {
    final updated = List<PlatformFile>.from(state.selectedFiles)..addAll(newFiles);
    state = state.copyWith(selectedFiles: updated);
  }

  void removeFile(PlatformFile file) {
    final updated = List<PlatformFile>.from(state.selectedFiles)..remove(file);
    state = state.copyWith(selectedFiles: updated);
  }

  void setVoiceFile(File? file) {
    state = state.copyWith(voiceFile: file, clearVoiceFile: file == null);
  }

  void setVoiceTranscript(String text) {
    state = state.copyWith(voiceTranscript: text);
  }

  void setRecordingState(bool recording) {
    state = state.copyWith(isRecording: recording);
  }

  /// Clears everything, including any run in flight.
  ///
  /// Called when the intake screen is opened. Without it the screen came back
  /// still holding the previous run's files, voice note and result, and a
  /// second analysis re-uploaded the first run's documents alongside the new
  /// ones.
  void reset() {
    _subscription?.cancel();
    _subscription = null;
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
    _subscription?.cancel();
    _subscription = null;
    state = state.copyWith(
      selectedFiles: const [],
      clearVoiceFile: true,
      voiceTranscript: '',
      isRecording: false,
      isExtracting: false,
      clearResult: true,
      clearSessionId: true,
      errorMessage: null,
    );
  }

  /// Uploads the intake and follows the backend pipeline to completion.
  ///
  /// Returns true when there is a result to pre-fill the Post Case form with.
  /// Progress reaches the UI only through backend events — there is no timer
  /// and no simulated advancement anywhere in this flow.
  Future<bool> startExtraction() async {
    if (state.selectedFiles.isEmpty) {
      state = state.copyWith(
        errorMessage:
            'Please upload at least one document. A voice note or written notes can add extra detail.',
      );
      return false;
    }

    // A second press while a run is in flight would upload the same documents
    // again and leave two subscriptions racing to set the result.
    if (state.isExtracting) return false;

    // Claim the run and wipe the previous one *synchronously*, before the first
    // await. Both used to sit after `_subscription.cancel()`, which meant a
    // second press in the same frame still saw `isExtracting == false` and
    // started a duplicate upload, and the old result stayed readable for that
    // window. Every run now starts from nothing: no previous extraction, no
    // previous session id, no stale error.
    state = state.copyWith(
      isExtracting: true,
      progress: const AnalysisProgress(
        stage: 'uploading',
        message: 'Uploading your documents…',
      ),
      clearResult: true,
      clearSessionId: true,
      errorMessage: null,
    );

    // Abandon anything still streaming from the previous run before its events
    // can be mistaken for this one's.
    await _subscription?.cancel();
    _subscription = null;

    final completer = Completer<bool>();

    try {
      final sessionId = await _repository.startAnalysis(
        files: state.selectedFiles,
        voiceFile: state.voiceFile,
        issueDescription: state.voiceTranscript,
      );

      if (!mounted) return false;
      state = state.copyWith(sessionId: sessionId);

      _subscription = _repository.watch(sessionId).listen(
        (event) {
          if (!mounted) return;

          if (event.progress != null) {
            state = state.copyWith(progress: event.progress);
            return;
          }

          if (event.result != null) {
            state = state.copyWith(
              isExtracting: false,
              progress: const AnalysisProgress(
                stage: 'completed',
                message: 'Analysis complete',
                percent: 100,
              ),
              result: event.result,
            );
            if (!completer.isCompleted) completer.complete(true);
            return;
          }

          if (event.error != null) {
            state = state.copyWith(isExtracting: false, errorMessage: event.error);
            if (!completer.isCompleted) completer.complete(false);
          }
        },
        onError: (Object e) {
          if (mounted) {
            state = state.copyWith(isExtracting: false, errorMessage: _friendlyError(e));
          }
          if (!completer.isCompleted) completer.complete(false);
        },
        onDone: () {
          if (completer.isCompleted) return;

          // Reaching here means the stream closed without delivering a result
          // for *this* run. Reading `state.result` to decide would report
          // success off whatever the previous document left behind, which is
          // how a failed second analysis used to open the form pre-filled with
          // the first document's details.
          if (mounted) {
            state = state.copyWith(
              isExtracting: false,
              errorMessage:
                  'The analysis finished without returning any details. Please try again.',
            );
          }
          completer.complete(false);
        },
      );

      return completer.future;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isExtracting: false, errorMessage: _friendlyError(e));
      }
      return false;
    }
  }

  /// Turns transport failures into something a client can act on.
  String _friendlyError(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.connectionTimeout:
          return 'Uploading your documents took too long. '
              'Please check your connection and try again.';
        case DioExceptionType.connectionError:
          return 'Could not reach the server. Please check your connection.';
        default:
          final message = e.response?.data is Map ? e.response?.data['message'] : null;
          if (message is String && message.isNotEmpty) return message;
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
