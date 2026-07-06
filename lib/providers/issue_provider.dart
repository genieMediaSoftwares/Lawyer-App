import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../models/issue_model.dart';
import '../models/document_model.dart';

final issuesProvider = StateNotifierProvider<IssueNotifier, AsyncValue<List<IssueModel>>>((ref) {
  return IssueNotifier();
});

class IssueNotifier extends StateNotifier<AsyncValue<List<IssueModel>>> {
  IssueNotifier() : super(const AsyncValue.loading()) {
    fetchIssues();
  }

  Future<void> fetchIssues() async {
    try {
      state = const AsyncValue.loading();
      final response = await DioClient.dio.get("/issues");
      if (response.data != null && response.data['success'] == true) {
        final list = response.data['data'] as List;
        final issues = list.map((item) => IssueModel.fromJson(item)).toList();
        state = AsyncValue.data(issues);
      } else {
        state = AsyncValue.error("Failed to load issues", StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<IssueModel?> createIssue({
    required String title,
    required String description,
    required String category,
    required String urgency,
    required String preferredLanguage,
    required String location,
    required String preferredMode,
    List<DocumentModel>? documents,
    List<DocumentModel>? images,
  }) async {
    try {
      final response = await DioClient.dio.post("/issues/create", data: {
        "title": title,
        "description": description,
        "category": category,
        "urgency": urgency,
        "preferredLanguage": preferredLanguage,
        "location": location,
        "preferredMode": preferredMode,
        "documents": documents?.map((d) => d.toJson()).toList() ?? [],
        "images": images?.map((d) => d.toJson()).toList() ?? [],
      });

      if (response.data != null && response.data['success'] == true) {
        final newIssue = IssueModel.fromJson(response.data['data']);
        state.whenData((currentIssues) {
          state = AsyncValue.data([newIssue, ...currentIssues]);
        });
        return newIssue;
      }
    } catch (e) {
      // Handle error
    }
    return null;
  }

  Future<bool> updateIssueStatus(String issueId, String status) async {
    try {
      final response = await DioClient.dio.put("/issues/$issueId", data: {
        "status": status,
      });

      if (response.data != null && response.data['success'] == true) {
        await fetchIssues();
        return true;
      }
    } catch (e) {
      // Handle error
    }
    return false;
  }

  Future<bool> deleteIssue(String issueId) async {
    try {
      final response = await DioClient.dio.delete("/issues/$issueId");
      if (response.data != null && response.data['success'] == true) {
        state.whenData((currentIssues) {
          state = AsyncValue.data(currentIssues.where((i) => i.id != issueId).toList());
        });
        return true;
      }
    } catch (e) {
      // Handle error
    }
    return false;
  }
}
