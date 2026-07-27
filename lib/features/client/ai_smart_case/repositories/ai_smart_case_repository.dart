import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/ai_smart_case_models.dart';

class AISmartCaseRepository {
  /// Upload documents and optional voice recording to analyze with AI
  Future<AISmartCaseSessionResponse> analyzeSmartCase({
    required List<File> files,
    File? voiceFile,
    String? issueDescription,
  }) async {
    final formData = FormData();

    for (var file in files) {
      final fileName = file.path.split('/').last.split('\\').last;
      formData.files.add(
        MapEntry(
          'documents',
          await MultipartFile.fromFile(
            file.path,
            filename: fileName,
          ),
        ),
      );
    }

    if (voiceFile != null) {
      final voiceName = voiceFile.path.split('/').last.split('\\').last;
      formData.files.add(
        MapEntry(
          'voice',
          await MultipartFile.fromFile(
            voiceFile.path,
            filename: voiceName,
          ),
        ),
      );
    }

    if (issueDescription != null && issueDescription.isNotEmpty) {
      formData.fields.add(MapEntry('issueDescription', issueDescription));
    }

    final response = await DioClient.dio.post(
      '/ai/smart-case/analyze',
      data: formData,
      options: Options(
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      ),
    );

    if (response.statusCode == 200 && response.data != null) {
      return AISmartCaseSessionResponse.fromJson(response.data);
    } else {
      throw Exception(response.data?['message'] ?? 'Failed to analyze smart case.');
    }
  }

  /// Submit answers to follow-up questions
  Future<AISmartCaseSessionResponse> answerQuestions({
    required String sessionId,
    required List<Map<String, String>> answers,
  }) async {
    final response = await DioClient.dio.post(
      '/ai/smart-case/answer-questions',
      data: {
        'sessionId': sessionId,
        'answers': answers,
      },
    );

    if (response.statusCode == 200 && response.data != null) {
      return AISmartCaseSessionResponse.fromJson(response.data);
    } else {
      throw Exception(response.data?['message'] ?? 'Failed to submit answers.');
    }
  }

  /// Confirm and create final case in MongoDB
  Future<Map<String, dynamic>> confirmCreateCase({
    required String sessionId,
    required String title,
    required String description,
    required String category,
    required String priority,
    String? selectedLawyerId,
    String? location,
  }) async {
    final response = await DioClient.dio.post(
      '/ai/smart-case/confirm-create',
      data: {
        'sessionId': sessionId,
        'title': title,
        'description': description,
        'category': category,
        'priority': priority,
        if (selectedLawyerId != null && selectedLawyerId.isNotEmpty)
          'selectedLawyerId': selectedLawyerId,
        if (location != null && location.isNotEmpty) 'location': location,
      },
    );

    if (response.statusCode == 200 && response.data != null) {
      return response.data['data'] ?? response.data;
    } else {
      throw Exception(response.data?['message'] ?? 'Failed to create case.');
    }
  }
}
