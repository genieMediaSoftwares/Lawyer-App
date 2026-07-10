import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../core/network/dio_client.dart';
import '../models/case_model.dart';
import '../models/document_model.dart';
import 'auth_provider.dart';

final casesProvider = StateNotifierProvider<CaseNotifier, AsyncValue<List<CaseModel>>>((ref) {
  final authState = ref.watch(authProvider);
  final notifier = CaseNotifier(ref);
  notifier.syncSocket(authState.userId);
  return notifier;
});

class CaseNotifier extends StateNotifier<AsyncValue<List<CaseModel>>> {
  IO.Socket? _socket;
  String? _currentUserId;

  CaseNotifier(Ref ref) : super(const AsyncValue.loading()) {
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
    String? subcategory,
    required String location,
    required String urgency,
    String? preferredCourt,
    List<DocumentModel>? documents,
    String? selectedLawyer,
  }) async {
    try {
      final response = await DioClient.dio.post("/cases", data: {
        "title": title,
        "description": description,
        "category": category,
        "subcategory": subcategory ?? "",
        "location": location,
        "budgetRange": "",
        "urgency": urgency,
        "preferredCourt": preferredCourt ?? "",
        "documents": documents?.map((d) => d.toJson()).toList() ?? [],
        "selectedLawyer": selectedLawyer,
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

  Future<bool> acceptCaseRequest(String caseId) async {
    try {
      final response = await DioClient.dio.post("/cases/$caseId/accept-request");
      if (response.data != null && response.data['success'] == true) {
        await fetchCases();
        return true;
      }
    } catch (e) {
      // Handle error
    }
    return false;
  }

  Future<bool> startCase(String caseId) async {
    try {
      final response = await DioClient.dio.post("/cases/$caseId/start");
      if (response.data != null && response.data['success'] == true) {
        await fetchCases();
        return true;
      }
    } catch (e) {
      // Handle error
    }
    return false;
  }

  Future<bool> markCaseCompleted(String caseId) async {
    try {
      final response = await DioClient.dio.post("/cases/$caseId/complete");
      if (response.data != null && response.data['success'] == true) {
        await fetchCases();
        return true;
      }
    } catch (e) {
      // Handle error
    }
    return false;
  }

  Future<bool> rejectCaseRequest(String caseId) async {
    try {
      final response = await DioClient.dio.post("/cases/$caseId/reject-request");
      if (response.data != null && response.data['success'] == true) {
        await fetchCases();
        return true;
      }
    } catch (e) {
      // Handle error
    }
    return false;
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
    String estimatedResponseTime = "24 hours",
    String consultationMode = "Video",
    String availability = "Mon-Fri 9AM-5PM",
  }) async {
    try {
      final response = await DioClient.dio.post("/cases/$caseId/proposals", data: {
        "feeProposal": fee.toInt(),
        "message": message,
        "estimatedResponseTime": estimatedResponseTime,
        "consultationMode": consultationMode,
        "availability": availability,
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

  Future<bool> submitCaseReview(String caseId, int rating, String review) async {
    try {
      final response = await DioClient.dio.post("/cases/$caseId/review", data: {
        "rating": rating,
        "review": review,
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

  void syncSocket(String? userId) {
    if (userId == _currentUserId) return;
    _currentUserId = userId;

    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;

    if (userId == null || userId.isEmpty) return;

    try {
      _socket = IO.io('http://localhost:5000/cases', IO.OptionBuilder()
        .setTransports(['websocket'])
        .build());

      _socket!.connect();

      _socket!.onConnect((_) {
        _socket!.emit('join', {'userId': userId});
      });

      _socket!.on('case_updated', (_) {
        fetchCases();
      });
    } catch (e) {
      // socket connection error
    }
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }
}

final caseSearchProvider = StateProvider<String>((ref) => "");
final caseFilterProvider = StateProvider<String>((ref) => "Newest");

final filteredCasesProvider = Provider<AsyncValue<List<CaseModel>>>((ref) {
  final casesState = ref.watch(casesProvider);
  final searchQuery = ref.watch(caseSearchProvider).toLowerCase();
  final sortBy = ref.watch(caseFilterProvider);

  return casesState.when(
    data: (cases) {
      var list = List<CaseModel>.from(cases);
      
      // Search
      if (searchQuery.isNotEmpty) {
        list = list.where((c) {
          final idMatch = c.id.toLowerCase().contains(searchQuery);
          final titleMatch = c.title.toLowerCase().contains(searchQuery);
          final descMatch = c.description.toLowerCase().contains(searchQuery);
          final catMatch = c.category.toLowerCase().contains(searchQuery);
          final lName = (c.selectedLawyerName ?? c.assignedLawyerName ?? "").toLowerCase();
          final court = (c.preferredCourt ?? "").toLowerCase();
          return idMatch || titleMatch || descMatch || catMatch || lName.contains(searchQuery) || court.contains(searchQuery);
        }).toList();
      }

      // Sort
      if (sortBy == "Newest") {
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else if (sortBy == "Oldest") {
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      } else if (sortBy == "Status") {
        list.sort((a, b) => a.status.compareTo(b.status));
      } else if (sortBy == "Issue") {
        list.sort((a, b) => a.category.compareTo(b.category));
      } else if (sortBy == "Lawyer") {
        list.sort((a, b) {
          final nameA = a.selectedLawyerName ?? a.assignedLawyerName ?? "";
          final nameB = b.selectedLawyerName ?? b.assignedLawyerName ?? "";
          return nameA.compareTo(nameB);
        });
      } else if (sortBy == "Location") {
        list.sort((a, b) => a.location.compareTo(b.location));
      }

      return AsyncValue.data(list);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
  );
});

final caseDetailsProvider = StateNotifierProvider.family<CaseDetailsNotifier, AsyncValue<CaseModel?>, String>((ref, caseId) {
  return CaseDetailsNotifier(caseId);
});

class CaseDetailsNotifier extends StateNotifier<AsyncValue<CaseModel?>> {
  final String caseId;

  CaseDetailsNotifier(this.caseId) : super(const AsyncValue.loading()) {
    fetchCaseDetails();
  }

  Future<void> fetchCaseDetails() async {
    try {
      state = const AsyncValue.loading();
      final response = await DioClient.dio.get("/cases/$caseId");
      if (response.data != null && response.data['success'] == true) {
        final caseItem = CaseModel.fromJson(response.data['data']);
        state = AsyncValue.data(caseItem);
      } else {
        state = AsyncValue.error("Failed to load case details", StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
