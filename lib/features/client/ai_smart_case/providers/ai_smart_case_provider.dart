import 'dart:io';
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

  AISmartCaseState copyWith({
    List<File>? selectedFiles,
    File? voiceFile,
    String? voiceTranscript,
    bool? isRecording,
    bool? isAnalyzing,
    int? processingStepIndex,
    String? processingStepMessage,
    AISmartCaseSessionResponse? sessionResponse,
    RecommendedLawyer? selectedLawyer,
    Map<String, String>? userAnswers,
    bool? isCreatingCase,
    Map<String, dynamic>? createdCaseData,
    String? errorMessage,
  }) {
    return AISmartCaseState(
      selectedFiles: selectedFiles ?? this.selectedFiles,
      voiceFile: voiceFile ?? this.voiceFile,
      voiceTranscript: voiceTranscript ?? this.voiceTranscript,
      isRecording: isRecording ?? this.isRecording,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      processingStepIndex: processingStepIndex ?? this.processingStepIndex,
      processingStepMessage: processingStepMessage ?? this.processingStepMessage,
      sessionResponse: sessionResponse ?? this.sessionResponse,
      selectedLawyer: selectedLawyer ?? this.selectedLawyer,
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
    state = state.copyWith(voiceFile: file);
  }

  void setVoiceTranscript(String text) {
    state = state.copyWith(voiceTranscript: text);
  }

  void setRecordingState(bool recording) {
    state = state.copyWith(isRecording: recording);
  }

  void selectLawyer(RecommendedLawyer? lawyer) {
    state = state.copyWith(selectedLawyer: lawyer);
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
    if (state.selectedFiles.isEmpty && state.voiceFile == null && state.voiceTranscript.isEmpty) {
      state = state.copyWith(errorMessage: "Please upload at least one document or record a voice note.");
      return false;
    }

    state = state.copyWith(
      isAnalyzing: true,
      processingStepIndex: 0,
      processingStepMessage: "Uploading Documents...",
      errorMessage: null,
    );

    try {
      // Step simulation for animated progress UI
      await Future.delayed(const Duration(milliseconds: 600));
      state = state.copyWith(processingStepIndex: 1, processingStepMessage: "Google Cloud Vision OCR Processing...");
      
      await Future.delayed(const Duration(milliseconds: 700));
      state = state.copyWith(processingStepIndex: 2, processingStepMessage: "AI Legal Domain Understanding...");

      await Future.delayed(const Duration(milliseconds: 600));
      state = state.copyWith(processingStepIndex: 3, processingStepMessage: "Document Classification (FIR, Sale Deed, Notice)...");

      await Future.delayed(const Duration(milliseconds: 600));
      state = state.copyWith(processingStepIndex: 4, processingStepMessage: "Generating Case Title & Description...");

      final response = await _repository.analyzeSmartCase(
        files: state.selectedFiles,
        voiceFile: state.voiceFile,
        issueDescription: state.voiceTranscript,
      );

      state = state.copyWith(processingStepIndex: 5, processingStepMessage: "Checking Duplicate Cases in MongoDB...");
      await Future.delayed(const Duration(milliseconds: 500));

      state = state.copyWith(processingStepIndex: 6, processingStepMessage: "Finding Top Recommended Verified Lawyers...");
      await Future.delayed(const Duration(milliseconds: 500));

      RecommendedLawyer? defaultLawyer;
      if (response.recommendedLawyers.isNotEmpty) {
        defaultLawyer = response.recommendedLawyers.first;
      }

      state = state.copyWith(
        isAnalyzing: false,
        processingStepIndex: 7,
        processingStepMessage: "AI Analysis Ready!",
        sessionResponse: response,
        selectedLawyer: defaultLawyer,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isAnalyzing: false,
        errorMessage: e.toString().replaceAll("Exception: ", ""),
      );
      return false;
    }
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
        errorMessage: e.toString().replaceAll("Exception: ", ""),
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

      state = state.copyWith(
        isCreatingCase: false,
        createdCaseData: result,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isCreatingCase: false,
        errorMessage: e.toString().replaceAll("Exception: ", ""),
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
