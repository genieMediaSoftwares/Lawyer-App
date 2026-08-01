import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/admin_models.dart';
import '../models/appointment_model.dart';
import '../models/case_model.dart';
import '../models/document_model.dart';
import '../models/issue_model.dart';
import '../repositories/admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository();
});

// Dashboard Stats Provider
final adminStatsProvider = FutureProvider.autoDispose<AdminStatsModel>((
  ref,
) async {
  final repo = ref.watch(adminRepositoryProvider);
  return await repo.getDashboardStats();
});

// Clients Search & Filter state parameters
class AdminClientFilter {
  final String search;
  final String status;
  AdminClientFilter({this.search = '', this.status = 'all'});

  AdminClientFilter copyWith({String? search, String? status}) {
    return AdminClientFilter(
      search: search ?? this.search,
      status: status ?? this.status,
    );
  }
}

final adminClientFilterProvider = StateProvider<AdminClientFilter>(
  (ref) => AdminClientFilter(),
);

final adminClientsProvider =
    FutureProvider.autoDispose<List<AdminClientSummary>>((ref) async {
      final repo = ref.watch(adminRepositoryProvider);
      final filter = ref.watch(adminClientFilterProvider);
      return await repo.getClients(
        search: filter.search,
        status: filter.status,
      );
    });

// Lawyers Search & Filter state
class AdminLawyerFilter {
  final String search;
  final String verificationStatus;
  AdminLawyerFilter({this.search = '', this.verificationStatus = 'all'});

  AdminLawyerFilter copyWith({String? search, String? verificationStatus}) {
    return AdminLawyerFilter(
      search: search ?? this.search,
      verificationStatus: verificationStatus ?? this.verificationStatus,
    );
  }
}

final adminLawyerFilterProvider = StateProvider<AdminLawyerFilter>(
  (ref) => AdminLawyerFilter(),
);

final adminLawyersProvider =
    FutureProvider.autoDispose<List<AdminLawyerSummary>>((ref) async {
      final repo = ref.watch(adminRepositoryProvider);
      final filter = ref.watch(adminLawyerFilterProvider);
      return await repo.getLawyers(
        search: filter.search,
        verificationStatus: filter.verificationStatus,
      );
    });

final adminPendingLawyersProvider =
    FutureProvider.autoDispose<List<AdminLawyerSummary>>((ref) async {
      final repo = ref.watch(adminRepositoryProvider);
      return await repo.getLawyers(verificationStatus: 'pending');
    });

// Cases Provider
class AdminCaseFilter {
  final String search;
  final String status;
  AdminCaseFilter({this.search = '', this.status = 'all'});
}

final adminCaseFilterProvider = StateProvider<AdminCaseFilter>(
  (ref) => AdminCaseFilter(),
);

final adminCasesProvider = FutureProvider.autoDispose<List<CaseModel>>((
  ref,
) async {
  final repo = ref.watch(adminRepositoryProvider);
  final filter = ref.watch(adminCaseFilterProvider);
  return await repo.getCases(search: filter.search, status: filter.status);
});

// Documents Provider
final adminDocumentsProvider = FutureProvider.autoDispose<List<DocumentModel>>((
  ref,
) async {
  final repo = ref.watch(adminRepositoryProvider);
  return await repo.getDocuments();
});

// AI Analytics Provider
final adminAiAnalyticsProvider =
    FutureProvider.autoDispose<AdminAiAnalyticsModel>((ref) async {
      final repo = ref.watch(adminRepositoryProvider);
      return await repo.getAiAnalytics();
    });

// Support Tickets Provider
final adminSupportTicketsProvider =
    FutureProvider.autoDispose<List<IssueModel>>((ref) async {
      final repo = ref.watch(adminRepositoryProvider);
      return await repo.getSupportTickets();
    });

// System Analytics Provider
final adminAnalyticsProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) async {
    final repo = ref.watch(adminRepositoryProvider);
    return await repo.getAnalyticsData();
  },
);

// Admin Appointments Provider
final adminAppointmentsProvider =
    FutureProvider.autoDispose<List<AppointmentModel>>((ref) async {
      final repo = ref.watch(adminRepositoryProvider);
      return await repo.getAppointments();
    });
