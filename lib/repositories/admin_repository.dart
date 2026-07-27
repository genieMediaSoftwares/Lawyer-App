import '../core/network/dio_client.dart';
import '../models/admin_models.dart';
import '../models/appointment_model.dart';
import '../models/case_model.dart';
import '../models/document_model.dart';
import '../models/issue_model.dart';

class AdminRepository {
  // 1. Dashboard Stats
  Future<AdminStatsModel> getDashboardStats() async {
    try {
      final response = await DioClient.dio.get("/admin/stats");
      if (response.data != null && response.data['success'] == true) {
        return AdminStatsModel.fromJson(response.data['data']);
      }
    } catch (_) {}
    return AdminStatsModel(
      totalClients: 0,
      activeClients: 0,
      inactiveClients: 0,
      totalLawyers: 0,
      pendingVerifications: 0,
      approvedLawyers: 0,
      rejectedLawyers: 0,
      totalCases: 0,
      activeCases: 0,
      closedCases: 0,
      totalAppointments: 0,
      openAppointments: 0,
      totalSupportTickets: 0,
      openSupportTickets: 0,
      totalDocuments: 0,
      totalAiRequests: 0,
      casesOverview: {},
    );
  }

  // 2. Clients
  Future<List<AdminClientSummary>> getClients({String? search, String? status}) async {
    try {
      final response = await DioClient.dio.get(
        "/admin/clients",
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          if (status != null && status != 'all') 'status': status,
        },
      );
      if (response.data != null && response.data['success'] == true) {
        final list = response.data['data'] as List;
        return list.map((item) => AdminClientSummary.fromJson(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  // 3. Lawyers
  Future<List<AdminLawyerSummary>> getLawyers({String? search, String? verificationStatus}) async {
    try {
      final response = await DioClient.dio.get(
        "/admin/lawyers",
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          if (verificationStatus != null && verificationStatus != 'all') 'verificationStatus': verificationStatus,
        },
      );
      if (response.data != null && response.data['success'] == true) {
        final list = response.data['data'] as List;
        return list.map((item) => AdminLawyerSummary.fromJson(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  // 4. Verify Lawyer Action
  Future<bool> verifyLawyer({
    required String lawyerId,
    required String status, // 'verified', 'rejected'
    String? rejectionReason,
    bool? isActive,
  }) async {
    try {
      final response = await DioClient.dio.put(
        "/admin/lawyers/$lawyerId/verify",
        data: {
          'status': status,
          'rejectionReason': rejectionReason,
          'isActive': isActive,
        }..removeWhere((k, v) => v == null),
      );
      return response.data != null && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // 5. Cases
  Future<List<CaseModel>> getCases({String? status, String? search}) async {
    try {
      final response = await DioClient.dio.get(
        "/admin/cases",
        queryParameters: {
          'status': (status != null && status != 'all') ? status : null,
          'search': (search != null && search.isNotEmpty) ? search : null,
        }..removeWhere((k, v) => v == null),
      );
      if (response.data != null && response.data['success'] == true) {
        final list = response.data['data'] as List;
        return list.map((item) => CaseModel.fromJson(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  // 6. Update Case Status
  Future<bool> updateCaseStatus(String caseId, String status, {String? priority}) async {
    try {
      final response = await DioClient.dio.put(
        "/admin/cases/$caseId/status",
        data: {
          'status': status,
          'priority': priority,
        }..removeWhere((k, v) => v == null),
      );
      return response.data != null && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // 7. Documents Vault
  Future<List<DocumentModel>> getDocuments({String? search, String? category}) async {
    try {
      final response = await DioClient.dio.get(
        "/admin/documents",
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          if (category != null && category != 'all') 'category': category,
        },
      );
      if (response.data != null && response.data['success'] == true) {
        final list = response.data['data'] as List;
        return list.map((item) => DocumentModel.fromJson(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  // 8. AI Analytics
  Future<AdminAiAnalyticsModel> getAiAnalytics() async {
    try {
      final response = await DioClient.dio.get("/admin/ai-analytics");
      if (response.data != null && response.data['success'] == true) {
        return AdminAiAnalyticsModel.fromJson(response.data['data']);
      }
    } catch (_) {}
    return AdminAiAnalyticsModel(
      totalQuestions: 0,
      successRate: "0%",
      avgResponseTime: "0 sec",
      tokensUsed: "0",
      topQuestions: [],
    );
  }

  // 9. Support Tickets
  Future<List<IssueModel>> getSupportTickets({String? status, String? search}) async {
    try {
      final response = await DioClient.dio.get(
        "/admin/support-tickets",
        queryParameters: {
          if (status != null && status != 'all') 'status': status,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );
      if (response.data != null && response.data['success'] == true) {
        final list = response.data['data'] as List;
        return list.map((item) => IssueModel.fromJson(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  // Update Support Ticket Status
  Future<bool> updateSupportTicket(String ticketId, String status) async {
    try {
      final response = await DioClient.dio.put(
        "/admin/support-tickets/$ticketId",
        data: {'status': status},
      );
      return response.data != null && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // 10. Broadcast Push Notification
  Future<bool> broadcastNotification(String title, String message, String targetRole) async {
    try {
      final response = await DioClient.dio.post(
        "/admin/notifications/broadcast",
        data: {
          'title': title,
          'message': message,
          'targetRole': targetRole,
        },
      );
      return response.data != null && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // 11. System Analytics Data
  Future<Map<String, dynamic>> getAnalyticsData() async {
    try {
      final response = await DioClient.dio.get("/admin/analytics");
      if (response.data != null && response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }
    } catch (_) {}
    return {
      'monthlyStats': [],
      'clientGrowthRate': '0%',
      'lawyerGrowthRate': '0%',
      'caseResolutionRate': '0%',
    };
  }

  // 12. Reports Data
  Future<Map<String, dynamic>> getReportData(String reportType) async {
    try {
      final response = await DioClient.dio.get(
        "/admin/reports",
        queryParameters: {'reportType': reportType},
      );
      if (response.data != null && response.data['success'] == true) {
        return response.data;
      }
    } catch (_) {}
    return {'headers': [], 'rows': []};
  }

  // 13. Appointments Data
  Future<List<AppointmentModel>> getAppointments() async {
    try {
      final response = await DioClient.dio.get("/appointments");
      if (response.data != null && response.data['success'] == true) {
        final list = response.data['data'] as List;
        return list.map((item) => AppointmentModel.fromJson(item)).toList();
      }
    } catch (_) {}
    return [];
  }
}
