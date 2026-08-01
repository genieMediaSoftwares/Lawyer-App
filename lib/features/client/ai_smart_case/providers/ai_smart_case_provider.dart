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
  AISmartCaseState copyWith({
    List<PlatformFile>? selectedFiles,
    File? voiceFile,
    bool clearVoiceFile = false,
    String? voiceTranscript,
    bool? isRecording,
    bool? isExtracting,
    String? sessionId,
    AnalysisProgress? progress,
    ExtractionResult? result,
    String? errorMessage,
  }) {
    return AISmartCaseState(
      selectedFiles: selectedFiles ?? this.selectedFiles,
      voiceFile: clearVoiceFile ? null : (voiceFile ?? this.voiceFile),
      voiceTranscript: voiceTranscript ?? this.voiceTranscript,
      isRecording: isRecording ?? this.isRecording,
      isExtracting: isExtracting ?? this.isExtracting,
      sessionId: sessionId ?? this.sessionId,
      progress: progress ?? this.progress,
      result: result ?? this.result,
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

    await _subscription?.cancel();
    _subscription = null;

    state = state.copyWith(
      isExtracting: true,
      progress: const AnalysisProgress(
        stage: 'uploading',
        message: 'Uploading your documents…',
      ),
      result: null,
      errorMessage: null,
    );

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
          if (!completer.isCompleted) completer.complete(state.result != null);
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
