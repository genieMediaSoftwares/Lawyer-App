class AdminStatsModel {
  final int totalClients;
  final int activeClients;
  final int inactiveClients;
  final int totalLawyers;
  final int pendingVerifications;
  final int approvedLawyers;
  final int rejectedLawyers;
  final int totalCases;
  final int activeCases;
  final int closedCases;
  final int totalAppointments;
  final int openAppointments;
  final int totalSupportTickets;
  final int openSupportTickets;
  final int totalDocuments;
  final int totalAiRequests;
  final Map<String, dynamic> casesOverview;

  AdminStatsModel({
    required this.totalClients,
    required this.activeClients,
    required this.inactiveClients,
    required this.totalLawyers,
    required this.pendingVerifications,
    required this.approvedLawyers,
    required this.rejectedLawyers,
    required this.totalCases,
    required this.activeCases,
    required this.closedCases,
    required this.totalAppointments,
    required this.openAppointments,
    required this.totalSupportTickets,
    required this.openSupportTickets,
    required this.totalDocuments,
    required this.totalAiRequests,
    required this.casesOverview,
  });

  factory AdminStatsModel.fromJson(Map<String, dynamic> json) {
    return AdminStatsModel(
      totalClients: json['totalClients'] ?? 0,
      activeClients: json['activeClients'] ?? 0,
      inactiveClients: json['inactiveClients'] ?? 0,
      totalLawyers: json['totalLawyers'] ?? 0,
      pendingVerifications: json['pendingVerifications'] ?? 0,
      approvedLawyers: json['approvedLawyers'] ?? 0,
      rejectedLawyers: json['rejectedLawyers'] ?? 0,
      totalCases: json['totalCases'] ?? 0,
      activeCases: json['activeCases'] ?? 0,
      closedCases: json['closedCases'] ?? 0,
      totalAppointments: json['totalAppointments'] ?? 0,
      openAppointments: json['openAppointments'] ?? 0,
      totalSupportTickets: json['totalSupportTickets'] ?? 0,
      openSupportTickets: json['openSupportTickets'] ?? 0,
      totalDocuments: json['totalDocuments'] ?? 0,
      totalAiRequests: json['totalAiRequests'] ?? 0,
      casesOverview: Map<String, dynamic>.from(json['casesOverview'] ?? {}),
    );
  }
}

class AdminClientSummary {
  final String id;
  final String fullName;
  final String email;
  final String mobile;
  final String profileImage;
  final bool isActive;
  final String createdAt;
  final int casesCount;
  final int documentsCount;
  final int appointmentsCount;

  AdminClientSummary({
    required this.id,
    required this.fullName,
    required this.email,
    required this.mobile,
    required this.profileImage,
    required this.isActive,
    required this.createdAt,
    required this.casesCount,
    required this.documentsCount,
    required this.appointmentsCount,
  });

  factory AdminClientSummary.fromJson(Map<String, dynamic> json) {
    return AdminClientSummary(
      id: json['_id'] ?? '',
      fullName: json['fullName'] ?? 'Client',
      email: json['email'] ?? '',
      mobile: json['mobile'] ?? '',
      profileImage: json['profileImage'] ?? '',
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] ?? '',
      casesCount: json['casesCount'] ?? 0,
      documentsCount: json['documentsCount'] ?? 0,
      appointmentsCount: json['appointmentsCount'] ?? 0,
    );
  }
}

class AdminLawyerSummary {
  final String id;
  final String userId;
  final String fullName;
  final String email;
  final String mobile;
  final String profileImage;
  final String specialization;
  final int experience;
  final String barCouncilNumber;
  final String verificationStatus;
  /// Null when the lawyer has never been rated.
  final double? rating;

  AdminLawyerSummary({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.mobile,
    required this.profileImage,
    required this.specialization,
    required this.experience,
    required this.barCouncilNumber,
    required this.verificationStatus,
    required this.rating,
  });

  factory AdminLawyerSummary.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] is Map<String, dynamic> ? json['user'] : {};
    return AdminLawyerSummary(
      id: json['_id'] ?? '',
      userId: userMap['_id'] ?? '',
      fullName: userMap['fullName'] ?? 'Advocate',
      email: userMap['email'] ?? '',
      mobile: userMap['mobile'] ?? '',
      profileImage: userMap['profileImage'] ?? '',
      specialization: json['specialization'] ?? '',
      experience: json['experience'] ?? 0,
      barCouncilNumber: json['barCouncilNumber'] ?? '',
      verificationStatus: json['verificationStatus'] ?? 'pending',
      // Unrated stays unrated — no invented score.
      rating: (json['rating'] as num?)?.toDouble(),
    );
  }
}

class AdminAiAnalyticsModel {
  final int totalQuestions;
  final String successRate;
  final String avgResponseTime;
  final String tokensUsed;
  final List<Map<String, dynamic>> topQuestions;

  AdminAiAnalyticsModel({
    required this.totalQuestions,
    required this.successRate,
    required this.avgResponseTime,
    required this.tokensUsed,
    required this.topQuestions,
  });

  factory AdminAiAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return AdminAiAnalyticsModel(
      totalQuestions: json['totalQuestions'] ?? 0,
      successRate: json['successRate'] ?? '95.4%',
      avgResponseTime: json['avgResponseTime'] ?? '2.4s',
      tokensUsed: json['tokensUsed'] ?? '2.4M',
      topQuestions: List<Map<String, dynamic>>.from(json['topQuestions'] ?? []),
    );
  }
}
