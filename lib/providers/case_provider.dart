import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../core/config/app_config.dart';
import '../core/network/dio_client.dart';
import '../core/storage/token_storage.dart';
import '../models/case_model.dart';
import '../models/document_model.dart';
import 'admin_provider.dart';
import 'auth_provider.dart';
import 'notification_provider.dart';


final casesProvider = StateNotifierProvider<CaseNotifier, AsyncValue<List<CaseModel>>>((ref) {
  final authState = ref.watch(authProvider);
  final notifier = CaseNotifier(ref);
  notifier.syncSocket(authState.userId);
  return notifier;
});

class CaseNotifier extends StateNotifier<AsyncValue<List<CaseModel>>> {
  io.Socket? _socket;
  String? _currentUserId;

  /// Why the last [createCase] failed, or null when it succeeded. The call
  /// returns null on every kind of failure, which left the Post Case screen
  /// with nothing to tell the client beyond "please try again".
  String? lastCreateError;

  /// Kept so a case change can fan out to every view derived from the case
  /// list. The constructor previously accepted this and threw it away, which
  /// is why posting a case refreshed My Cases but left the dashboards, badge
  /// counts and lawyer workspace showing stale data until they were reopened.
  final Ref _ref;

  CaseNotifier(this._ref) : super(const AsyncValue.loading()) {
    fetchCases();
  }

  /// Single fan-out point for "a case was created or changed".
  ///
  /// Called both by the `/cases` socket and directly after a local write, so
  /// the originating device updates immediately rather than waiting for its
  /// own broadcast to arrive. Everything downstream reads from these
  /// providers, so no screen needs its own refresh logic and none can drift.
  Future<void> caseChanged() async {
    // `lawyerWorkspaceLeadsProvider` and `lawyerWorkspaceClientsProvider` each
    // `ref.watch(casesProvider)`, so this one line already rebuilds them. They
    // must NOT be invalidated from here:
    // `Ref.invalidate` asserts `_debugAssertCanDependOn`, which walks the
    // target's ancestors and throws CircularDependencyError when it finds the
    // caller — and casesProvider is their ancestor. That throw propagated out
    // of caseChanged() and out of _submitCase(), so a case was created but the
    // success snackbar and the redirect home never ran.
    // Silent: the list is already on screen, and swapping it for a spinner on
    // every broadcast threw away the caller's tab/scroll context — including
    // the one that arrives moments after a local write as the echo of that
    // same write.
    await fetchCases(silent: true);

    // The admin dashboards fetch case-derived data from their own endpoints and
    // do not depend on this provider, so nothing else tells them a case
    // changed. Gated on the session actually being an admin one: those
    // endpoints reject client and lawyer tokens, so invalidating them
    // unconditionally fired a 403 on every case action.
    if (_ref.read(authProvider).role == UserRole.admin) {
      _ref.invalidate(adminCasesProvider);
      _ref.invalidate(adminStatsProvider);
    }

    // A new case raises notifications for the lawyers it reached.
    try {
      await _ref
          .read(notificationsProvider.notifier)
          .fetchNotifications(refresh: true);
    } catch (_) {
      // Notification refresh is best-effort; the case list is already current.
    }
  }

  /// Loads the case list.
  ///
  /// [silent] keeps whatever is already in [state] on screen while the request
  /// is in flight, instead of flipping to `AsyncValue.loading()`. Use it for a
  /// background reconcile after a local write; leave it false for a first load
  /// or a user-initiated retry, where the spinner is the point.
  Future<void> fetchCases({bool silent = false}) async {
    try {
      if (!silent) state = const AsyncValue.loading();
      final response = await DioClient.dio.get("/cases");
      if (response.data != null && response.data['success'] == true) {
        // IMPORTANT: On Flutter Web, `as List` throws a TypeError on raw JS
        // arrays ("Symbol($signatureRti)"). List.from() is safe on all platforms.
        final raw = response.data['data'];
        final list = raw is List ? raw : List.from(raw as Iterable? ?? []);
        final cases = list
            .map((item) => CaseModel.fromJson(
                item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{}))
            .toList();
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
    String? preferredCourt,
    List<DocumentModel>? documents,
    String? selectedLawyer,
    String? voiceUrl,
    String? voiceTranscript,
    String? city,
    String? district,
    String? stateName,
    String? country,
    double? latitude,
    double? longitude,
    String? placeId,
    double? claimAmount,
  }) async {
    lastCreateError = null;
    try {
      final response = await DioClient.dio.post("/cases", data: {
        "title": title,
        "description": description,
        "category": category,
        "subcategory": subcategory ?? "",
        "location": location,
        "budgetRange": "",
        // `urgency` is deliberately absent: the form no longer asks for it, so
        // the server applies its own default rather than the client inventing
        // one. The lawyer-facing screens read it back from the case either way.
        "preferredCourt": preferredCourt ?? "",
        "documents": documents?.map((d) => d.toJson()).toList() ?? [],
        "selectedLawyer": selectedLawyer,
        "voiceUrl": voiceUrl ?? "",
        "voiceTranscript": voiceTranscript ?? "",
        "city": city ?? "",
        "district": district ?? "",
        "state": stateName ?? "",
        "country": country ?? "",
        "latitude": latitude ?? 0.0,
        "longitude": longitude ?? 0.0,
        "placeId": placeId ?? "",
        // Extracted from documents by the AI intake; there is no manual input
        // for it on the form.
        "claimAmount": claimAmount,
      });

      if (response.data != null && response.data['success'] == true) {
        final raw = response.data['data'];
        final newCase = CaseModel.fromJson(
            raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
        state.whenData((currentCases) {
          state = AsyncValue.data([newCase, ...currentCases]);
        });
        return newCase;
      }
      lastCreateError = response.data?['message']?.toString();
    } catch (e) {
      // The server's own message ("Category is required", a validation error)
      // is far more useful to the client than the Dio wrapper around it.
      lastCreateError = e is DioException
          ? (e.response?.data is Map
                ? e.response?.data['message']?.toString()
                : null) ??
                e.message
          : e.toString();
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
        // The server has already set status to "Completed" — apply it to the
        // copy in memory so the case moves between the caller's tabs and the
        // counts settle on this frame, rather than a round-trip later.
        _patchCase(
          caseId,
          (c) => c.copyWith(status: 'Completed', completedAt: DateTime.now()),
        );
        // Reconcile against the server (completedAt, notifications, anything
        // else it touched) without disturbing what is on screen.
        await fetchCases(silent: true);
        return true;
      }
    } catch (e) {
      // Handle error
    }
    return false;
  }

  /// Replaces a single case in [state] with [update] applied to it.
  ///
  /// A no-op while the list is loading or errored — there is nothing to patch
  /// then, and the fetch that follows supplies the authoritative list anyway.
  void _patchCase(String caseId, CaseModel Function(CaseModel) update) {
    final cases = state.valueOrNull;
    if (cases == null) return;
    state = AsyncValue.data([
      for (final c in cases) c.id == caseId ? update(c) : c,
    ]);
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

  Future<void> syncSocket(String? userId) async {
    if (userId == _currentUserId) return;
    _currentUserId = userId;

    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;

    if (userId == null || userId.isEmpty) return;

    try {
      // The handshake is rejected without a valid JWT.
      final token = await TokenStorage().getToken();
      if (token == null || token.isEmpty) return;

      _socket = io.io(AppConfig.caseSocketUrl, io.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': token})
        .build());

      _socket!.connect();

      // The user's case-update room is joined server-side from the
      // authenticated handshake — no client-supplied userId is trusted.

      // One socket, one handler, one fan-out — so every screen that shows
      // case-derived data updates from the same event.
      _socket!.on('case_updated', (_) {
        caseChanged();
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
        final raw = response.data['data'];
        final caseItem = CaseModel.fromJson(
            raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
        state = AsyncValue.data(caseItem);
      } else {
        state = AsyncValue.error("Failed to load case details", StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
