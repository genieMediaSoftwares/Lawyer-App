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
    required String location,
    required String urgency,
    String? preferredCourt,
    List<DocumentModel>? documents,
  }) async {
    try {
      final response = await DioClient.dio.post("/cases", data: {
        "title": title,
        "description": description,
        "category": category,
        "location": location,
        "budgetRange": "",
        "urgency": urgency,
        "preferredCourt": preferredCourt ?? "",
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
      final response = await DioClient.dio.post("/cases/$caseId/proposals", data: {
        "feeProposal": fee.toInt(),
        "message": message,
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
