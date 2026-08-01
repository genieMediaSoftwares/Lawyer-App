import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_smart_case_models.dart';
import '../repositories/ai_smart_case_repository.dart';

final aiSmartCaseRepositoryProvider = Provider<AISmartCaseRepository>((ref) {
  return AISmartCaseRepository();
});

class AISmartCaseState {
  final List<File> selectedFiles;
  final File? voiceFile;
  final String voiceTranscript;
  final bool isRecording;
  final bool isAnalyzing;
  final int processingStepIndex;
  final String processingStepMessage;
  final AISmartCaseSessionResponse? sessionResponse;
  final RecommendedLawyer? selectedLawyer;
  final Map<String, String> userAnswers;
  final bool isCreatingCase;
  final Map<String, dynamic>? createdCaseData;
  final String? errorMessage;

  AISmartCaseState({
    this.selectedFiles = const [],
    this.voiceFile,
    this.voiceTranscript = '',
    this.isRecording = false,
    this.isAnalyzing = false,
    this.processingStepIndex = 0,
    this.processingStepMessage = '',
    this.sessionResponse,
    this.selectedLawyer,
    this.userAnswers = const {},
    this.isCreatingCase = false,
    this.createdCaseData,
    this.errorMessage,
  });

  /// Nullable fields use explicit sentinel flags rather than `x ?? this.x`.
  ///
  /// With the `??` form, passing null meant "leave unchanged", so
  /// `setVoiceFile(null)` and `selectLawyer(null)` silently did nothing — there
  /// was no way to remove a recording or deselect a lawyer.
  AISmartCaseState copyWith({
    List<File>? selectedFiles,
    File? voiceFile,
    bool clearVoiceFile = false,
    String? voiceTranscript,
    bool? isRecording,
    bool? isAnalyzing,
    int? processingStepIndex,
    String? processingStepMessage,
    AISmartCaseSessionResponse? sessionResponse,
    RecommendedLawyer? selectedLawyer,
    bool clearSelectedLawyer = false,
    Map<String, String>? userAnswers,
    bool? isCreatingCase,
    Map<String, dynamic>? createdCaseData,
    String? errorMessage,
  }) {
    return AISmartCaseState(
      selectedFiles: selectedFiles ?? this.selectedFiles,
      voiceFile: clearVoiceFile ? null : (voiceFile ?? this.voiceFile),
      voiceTranscript: voiceTranscript ?? this.voiceTranscript,
      isRecording: isRecording ?? this.isRecording,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      processingStepIndex: processingStepIndex ?? this.processingStepIndex,
      processingStepMessage:
          processingStepMessage ?? this.processingStepMessage,
      sessionResponse: sessionResponse ?? this.sessionResponse,
      selectedLawyer: clearSelectedLawyer
          ? null
          : (selectedLawyer ?? this.selectedLawyer),
      userAnswers: userAnswers ?? this.userAnswers,
      isCreatingCase: isCreatingCase ?? this.isCreatingCase,
      createdCaseData: createdCaseData ?? this.createdCaseData,
      errorMessage: errorMessage,
    );
  }
}

class AISmartCaseNotifier extends StateNotifier<AISmartCaseState> {
  final AISmartCaseRepository _repository;

  AISmartCaseNotifier(this._repository) : super(AISmartCaseState());

  void addFiles(List<File> newFiles) {
    final updated = List<File>.from(state.selectedFiles)..addAll(newFiles);
    state = state.copyWith(selectedFiles: updated);
  }

  void removeFile(File file) {
    final updated = List<File>.from(state.selectedFiles)..remove(file);
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

  void selectLawyer(RecommendedLawyer? lawyer) {
    state = state.copyWith(
      selectedLawyer: lawyer,
      clearSelectedLawyer: lawyer == null,
    );
  }

  void updateAnswer(String question, String answer) {
    final updated = Map<String, String>.from(state.userAnswers);
    updated[question] = answer;
    state = state.copyWith(userAnswers: updated);
  }

  void reset() {
    state = AISmartCaseState();
  }

  Future<bool> startIntakeAnalysis() async {
    if (state.selectedFiles.isEmpty &&
        state.voiceFile == null &&
        state.voiceTranscript.isEmpty) {
      state = state.copyWith(
        errorMessage:
            "Please upload at least one document or record a voice note.",
      );
      return false;
    }

    state = state.copyWith(
      isAnalyzing: true,
      processingStepIndex: 0,
      processingStepMessage: _progressStages.first,
      errorMessage: null,
    );

    // Advances the status text while the single backend call is in flight.
    //
    // These used to be `await`ed delays interleaved with the request, which
    // added ~3.5s to an already slow flow and announced stages ("Google Cloud
    // Vision OCR Processing…") before the files had even been uploaded. The
    // ticker now runs alongside the real work and is cancelled when it
    // finishes, so the request is never held up by the animation.
    final ticker = _startProgressTicker();

    try {
      final response = await _repository.analyzeSmartCase(
        files: state.selectedFiles,
        voiceFile: state.voiceFile,
        issueDescription: state.voiceTranscript,
      );

      ticker.cancel();

      state = state.copyWith(
        isAnalyzing: false,
        processingStepIndex: _progressStages.length,
        processingStepMessage: "Analysis ready",
        sessionResponse: response,
        // Pre-select the top recommendation, if there is one. When the list is
        // empty the review screen must prompt the user to pick a lawyer —
        // creating a case with no lawyer skips the appointment and the
        // notification entirely.
        selectedLawyer: response.recommendedLawyers.isNotEmpty
            ? response.recommendedLawyers.first
            : null,
        clearSelectedLawyer: response.recommendedLawyers.isEmpty,
      );

      return true;
    } catch (e) {
      ticker.cancel();
      state = state.copyWith(
        isAnalyzing: false,
        errorMessage: _friendlyError(e),
      );
      return false;
    }
  }

  static const _progressStages = [
    "Uploading documents…",
    "Reading document text…",
    "Transcribing voice note…",
    "Identifying the legal issue…",
    "Drafting case title and summary…",
    "Checking for duplicate cases…",
    "Matching you with advocates…",
  ];

  Timer _startProgressTicker() {
    return Timer.periodic(const Duration(seconds: 4), (timer) {
      final next = state.processingStepIndex + 1;
      if (next >= _progressStages.length) {
        // Hold on the last stage rather than looping or claiming completion.
        return;
      }
      state = state.copyWith(
        processingStepIndex: next,
        processingStepMessage: _progressStages[next],
      );
    });
  }

  /// Turns transport failures into something a client can act on.
  String _friendlyError(Object e) {
    final raw = e.toString().replaceAll("Exception: ", "");

    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.connectionTimeout:
          return "The analysis is taking longer than expected. "
              "Please check your connection and try again.";
        case DioExceptionType.connectionError:
          return "Could not reach the server. Please check your connection.";
        default:
          final message = e.response?.data is Map
              ? e.response?.data['message']
              : null;
          if (message is String && message.isNotEmpty) return message;
          return "Something went wrong while analysing your case. Please try again.";
      }
    }

    return raw;
  }

  Future<bool> submitFollowUpAnswers() async {
    final session = state.sessionResponse;
    if (session == null) return false;

    state = state.copyWith(isAnalyzing: true, errorMessage: null);

    try {
      final answersList = state.userAnswers.entries
          .map((e) => {'question': e.key, 'answer': e.value})
          .toList();

      final updatedSession = await _repository.answerQuestions(
        sessionId: session.sessionId,
        answers: answersList,
      );

      state = state.copyWith(
        isAnalyzing: false,
        sessionResponse: updatedSession,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isAnalyzing: false,
        errorMessage: _friendlyError(e),
      );
      return false;
    }
  }

  Future<bool> confirmAndCreateCase({
    required String title,
    required String description,
    required String category,
    required String priority,
  }) async {
    final session = state.sessionResponse;
    if (session == null) return false;

    state = state.copyWith(isCreatingCase: true, errorMessage: null);

    try {
      final result = await _repository.confirmCreateCase(
        sessionId: session.sessionId,
        title: title,
        description: description,
        category: category,
        priority: priority,
        selectedLawyerId: state.selectedLawyer?.userId,
      );

      state = state.copyWith(isCreatingCase: false, createdCaseData: result);
      return true;
    } catch (e) {
      state = state.copyWith(
        isCreatingCase: false,
        errorMessage: _friendlyError(e),
      );
      return false;
    }
  }
}

final aiSmartCaseProvider =
    StateNotifierProvider<AISmartCaseNotifier, AISmartCaseState>((ref) {
      final repo = ref.watch(aiSmartCaseRepositoryProvider);
      return AISmartCaseNotifier(repo);
    });
