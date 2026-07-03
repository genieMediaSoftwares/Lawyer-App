import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../models/case_model.dart';
import '../models/document_model.dart';

final casesProvider = StateNotifierProvider<CaseNotifier, AsyncValue<List<CaseModel>>>((ref) {
  return CaseNotifier();
});

class CaseNotifier extends StateNotifier<AsyncValue<List<CaseModel>>> {
  CaseNotifier() : super(const AsyncValue.loading()) {
    fetchCases();
  }

  Future<void> fetchCases() async {
    try {
      state = const AsyncValue.loading();
      final response = await DioClient.dio.get("/cases");
      if (response.data != null && response.data['success'] == true) {
        final list = response.data['data'] as List;
        final cases = list.map((item) => CaseModel.fromJson(item)).toList();
        state = AsyncValue.data(cases);
      } else {
        state = AsyncValue.error("Failed to load cases", StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<CaseModel?> createCase({
    required String title,
    required String description,
    required String category,
    required String location,
    required String budgetRange,
    required String urgency,
    List<DocumentModel>? documents,
  }) async {
    try {
      final response = await DioClient.dio.post("/cases", data: {
        "title": title,
        "description": description,
        "category": category,
        "location": location,
        "budgetRange": budgetRange,
        "urgency": urgency,
        "documents": documents?.map((d) => d.toJson()).toList() ?? [],
      });

      if (response.data != null && response.data['success'] == true) {
        final newCase = CaseModel.fromJson(response.data['data']);
        state.whenData((currentCases) {
          state = AsyncValue.data([newCase, ...currentCases]);
        });
        return newCase;
      }
    } catch (e) {
      // Handle error
    }
    return null;
  }

  Future<bool> acceptProposal(String caseId, String lawyerId) async {
    try {
      final response = await DioClient.dio.post("/cases/$caseId/accept", data: {
        "lawyerId": lawyerId,
      });

      if (response.data != null && response.data['success'] == true) {
        await fetchCases(); // Reload to refresh details
        return true;
      }
    } catch (e) {
      // Handle error
    }
    return false;
  }

  Future<bool> updateMilestone(String caseId, String milestoneTitle, bool isCompleted) async {
    try {
      final response = await DioClient.dio.put("/cases/$caseId/milestones", data: {
        "milestoneTitle": milestoneTitle,
        "isCompleted": isCompleted,
      });

      if (response.data != null && response.data['success'] == true) {
        await fetchCases();
        return true;
      }
    } catch (e) {
      // Handle error
    }
    return false;
  }

  Future<bool> submitProposal({
    required String caseId,
    required String lawyerId,
    required String message,
    required double fee,
  }) async {
    try {
      final response = await DioClient.dio.post("/cases/$caseId/proposal", data: {
        "lawyerId": lawyerId,
        "message": message,
        "fee": fee,
        "duration": "1 week",
      });

      if (response.data != null && response.data['success'] == true) {
        await fetchCases();
        return true;
      }
    } catch (e) {
      // Handle error
    }
    return false;
  }
}
