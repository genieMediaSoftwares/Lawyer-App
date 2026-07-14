import 'document_model.dart';

class CaseModel {
  final String id;
  final String clientId;
  final String clientName;
  final String clientImage;
  final String title;
  final String description;
  final String category;
  final String? subcategory;
  final String location;
  final String budgetRange;
  final String urgency;
  final String status;
  final String? preferredCourt;
  final List<DocumentModel> documents;
  final List<CaseProposalModel> proposals;
  final String? assignedLawyerId;
  final String? assignedLawyerName;
  final String? assignedLawyerImage;
  final List<MilestoneModel> milestones;
  final DateTime createdAt;
  final bool clientVerified;

  final String? selectedLawyerId;
  final String? selectedLawyerName;
  final String? selectedLawyerImage;
  final String? selectedLawyerSpecialization;
  final int? selectedLawyerExperience;
  final double? selectedLawyerRating;
  final int? selectedLawyerFee;
  final bool? selectedLawyerVerified;

  final String? assignedLawyerSpecialization;
  final int? assignedLawyerExperience;
  final double? assignedLawyerRating;
  final int? assignedLawyerFee;
  final bool? assignedLawyerVerified;
  final bool? assignedLawyerOnline;

  final String? caseOutcome;
  final String? claimAmount;
  final DateTime? consultationDate;
  final DateTime? nextHearing;
  final DateTime? closedDate;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final double? rating;
  final String? review;
  final String? voiceUrl;
  final String? voiceTranscript;

  CaseModel({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.clientImage,
    required this.title,
    required this.description,
    required this.category,
    this.subcategory,
    required this.location,
    required this.budgetRange,
    required this.urgency,
    required this.status,
    this.preferredCourt,
    required this.documents,
    required this.proposals,
    this.assignedLawyerId,
    this.assignedLawyerName,
    this.assignedLawyerImage,
    required this.milestones,
    required this.createdAt,
    this.clientVerified = false,
    this.selectedLawyerId,
    this.selectedLawyerName,
    this.selectedLawyerImage,
    this.selectedLawyerSpecialization,
    this.selectedLawyerExperience,
    this.selectedLawyerRating,
    this.selectedLawyerFee,
    this.selectedLawyerVerified,
    this.assignedLawyerSpecialization,
    this.assignedLawyerExperience,
    this.assignedLawyerRating,
    this.assignedLawyerFee,
    this.assignedLawyerVerified,
    this.assignedLawyerOnline,
    this.caseOutcome,
    this.claimAmount,
    this.consultationDate,
    this.nextHearing,
    this.closedDate,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.rating,
    this.review,
    this.voiceUrl,
    this.voiceTranscript,
  });

  factory CaseModel.fromJson(Map<String, dynamic> json) {
    // ── Safe helpers (Flutter Web: `as List` throws Symbol($signatureRti) on
    // raw JS arrays; List.from() is safe across all platforms) ──────────────
    List<T> safeList<T>(dynamic raw, T Function(dynamic) mapper) {
      if (raw == null) return [];
      try {
        return List<dynamic>.from(raw as Iterable)
            .map(mapper)
            .toList();
      } catch (_) {
        return [];
      }
    }

    int? safeInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return null;
    }

    double? safeDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return null;
    }

    DateTime? safeDate(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) {
        try { return DateTime.parse(v); } catch (_) { return null; }
      }
      return null;
    }

    final clientRaw = json['client'];
    final clientData = clientRaw is Map ? Map<String, dynamic>.from(clientRaw) : <String, dynamic>{};
    final cId = clientRaw is String ? clientRaw : (clientData['_id']?.toString() ?? '');

    final lawyerRaw = json['assignedLawyer'];
    final lawyerData = lawyerRaw is Map ? Map<String, dynamic>.from(lawyerRaw) : <String, dynamic>{};
    final lId = lawyerRaw is String ? lawyerRaw : (lawyerData['_id']?.toString() ?? '');
    final assignedProfileRaw = json['assignedLawyerProfile'];
    final assignedLawyerProfile = assignedProfileRaw is Map
        ? Map<String, dynamic>.from(assignedProfileRaw)
        : <String, dynamic>{};

    final selRaw = json['selectedLawyer'];
    final selLawyerData = selRaw is Map ? Map<String, dynamic>.from(selRaw) : <String, dynamic>{};
    final selLawyerId = selRaw is String ? selRaw : (selLawyerData['_id']?.toString() ?? '');
    final selProfileRaw = json['selectedLawyerProfile'];
    final selLawyerProfile = selProfileRaw is Map
        ? Map<String, dynamic>.from(selProfileRaw)
        : <String, dynamic>{};

    return CaseModel(
      id: json['_id']?.toString() ?? '',
      clientId: cId,
      clientName: clientData['fullName']?.toString() ?? '',
      clientImage: clientData['profileImage']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      clientVerified: clientData['isVerified'] == true,
      category: json['category']?.toString() ?? '',
      subcategory: json['subcategory']?.toString(),
      location: json['location']?.toString() ?? '',
      budgetRange: json['budgetRange']?.toString() ?? '',
      urgency: json['urgency']?.toString() ?? 'Flexible',
      status: json['status']?.toString() ?? 'Submitted',
      preferredCourt: json['preferredCourt']?.toString(),
      documents: safeList(json['documents'],
          (d) => DocumentModel.fromJson(Map<String, dynamic>.from(d is Map ? d : {}))),
      proposals: safeList(json['proposals'],
          (p) => CaseProposalModel.fromJson(Map<String, dynamic>.from(p is Map ? p : {}))),
      assignedLawyerId: lId.isNotEmpty ? lId : null,
      assignedLawyerName: lawyerData['fullName']?.toString(),
      assignedLawyerImage: lawyerData['profileImage']?.toString(),
      milestones: safeList(json['milestones'],
          (m) => MilestoneModel.fromJson(Map<String, dynamic>.from(m is Map ? m : {}))),
      createdAt: safeDate(json['createdAt']) ?? DateTime.now(),
      selectedLawyerId: selLawyerId.isNotEmpty ? selLawyerId : null,
      selectedLawyerName: selLawyerData['fullName']?.toString(),
      selectedLawyerImage: selLawyerData['profileImage']?.toString(),
      selectedLawyerSpecialization: selLawyerProfile['specialization']?.toString(),
      selectedLawyerExperience: safeInt(selLawyerProfile['experience']),
      selectedLawyerRating: safeDouble(selLawyerProfile['rating']),
      selectedLawyerFee: safeInt(selLawyerProfile['consultationFee']),
      selectedLawyerVerified: selLawyerData['isVerified'] == true,
      assignedLawyerSpecialization: assignedLawyerProfile['specialization']?.toString(),
      assignedLawyerExperience: safeInt(assignedLawyerProfile['experience']),
      assignedLawyerRating: safeDouble(assignedLawyerProfile['rating']),
      assignedLawyerFee: safeInt(assignedLawyerProfile['consultationFee']),
      assignedLawyerVerified: lawyerData['isVerified'] == true,
      assignedLawyerOnline: lawyerData['isActive'] != false,
      caseOutcome: json['caseOutcome']?.toString() ?? '',
      claimAmount: json['claimAmount']?.toString() ?? '',
      consultationDate: safeDate(json['consultationDate']),
      nextHearing: safeDate(json['nextHearing']),
      closedDate: safeDate(json['closedDate']),
      acceptedAt: safeDate(json['acceptedAt']),
      startedAt: safeDate(json['startedAt']),
      completedAt: safeDate(json['completedAt']),
      rating: safeDouble(json['rating']) ?? 0.0,
      review: json['review']?.toString() ?? '',
      voiceUrl: json['voiceUrl']?.toString(),
      voiceTranscript: json['voiceTranscript']?.toString(),
    );
  }
}

class CaseProposalModel {
  final String lawyerId;
  final String fullName;
  final String profileImage;
  final int feeProposal;
  final String message;
  final DateTime createdAt;

  CaseProposalModel({
    required this.lawyerId,
    required this.fullName,
    required this.profileImage,
    required this.feeProposal,
    required this.message,
    required this.createdAt,
  });

  factory CaseProposalModel.fromJson(Map<String, dynamic> json) {
    final lawyerRaw = json['lawyer'];
    final lawyerData = lawyerRaw is Map
        ? Map<String, dynamic>.from(lawyerRaw)
        : <String, dynamic>{};
    final lId = lawyerRaw is String
        ? lawyerRaw
        : (lawyerData['_id']?.toString() ?? '');

    DateTime? safeDate(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) {
        try { return DateTime.parse(v); } catch (_) { return null; }
      }
      return null;
    }

    return CaseProposalModel(
      lawyerId: lId,
      fullName: lawyerData['fullName']?.toString() ?? 'Lawyer',
      profileImage: lawyerData['profileImage']?.toString() ?? '',
      feeProposal: json['feeProposal'] is num
          ? (json['feeProposal'] as num).toInt()
          : 0,
      message: json['message']?.toString() ?? '',
      createdAt: safeDate(json['createdAt']) ?? DateTime.now(),
    );
  }
}

class MilestoneModel {
  final String title;
  final DateTime date;
  final bool isCompleted;

  MilestoneModel({
    required this.title,
    required this.date,
    required this.isCompleted,
  });

  factory MilestoneModel.fromJson(Map<String, dynamic> json) {
    DateTime safeDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is String && v.isNotEmpty) {
        try { return DateTime.parse(v); } catch (_) { return DateTime.now(); }
      }
      return DateTime.now();
    }

    return MilestoneModel(
      title: json['title']?.toString() ?? '',
      date: safeDate(json['date']),
      isCompleted: json['isCompleted'] == true,
    );
  }
}
