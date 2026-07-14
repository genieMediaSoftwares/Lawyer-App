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
    final clientData = json['client'] is Map<String, dynamic> ? json['client'] : {};
    final cId = json['client'] is String ? json['client'] : (clientData['_id'] ?? '');

    final lawyerData = json['assignedLawyer'] is Map<String, dynamic> ? json['assignedLawyer'] : {};
    final lId = json['assignedLawyer'] is String ? json['assignedLawyer'] : (lawyerData['_id'] ?? '');
    final assignedLawyerProfile = json['assignedLawyerProfile'] is Map<String, dynamic> ? json['assignedLawyerProfile'] : {};

    final selLawyerData = json['selectedLawyer'] is Map<String, dynamic> ? json['selectedLawyer'] : {};
    final selLawyerId = json['selectedLawyer'] is String ? json['selectedLawyer'] : (selLawyerData['_id'] ?? '');
    final selLawyerProfile = json['selectedLawyerProfile'] is Map<String, dynamic> ? json['selectedLawyerProfile'] : {};

    return CaseModel(
      id: json['_id'] ?? '',
      clientId: cId,
      clientName: clientData['fullName'] ?? '',
      clientImage: clientData['profileImage'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      clientVerified: clientData['isVerified'] ?? false,
      category: json['category'] ?? '',
      subcategory: json['subcategory'],
      location: json['location'] ?? '',
      budgetRange: json['budgetRange'] ?? '',
      urgency: json['urgency'] ?? 'Flexible',
      status: json['status'] ?? 'Submitted',
      preferredCourt: json['preferredCourt'],
      documents: (json['documents'] as List?)
              ?.map((d) => DocumentModel.fromJson(d))
              .toList() ??
          [],
      proposals: (json['proposals'] as List?)
              ?.map((p) => CaseProposalModel.fromJson(p))
              .toList() ??
          [],
      assignedLawyerId: lId.isNotEmpty ? lId : null,
      assignedLawyerName: lawyerData['fullName'],
      assignedLawyerImage: lawyerData['profileImage'],
      milestones: (json['milestones'] as List?)
              ?.map((m) => MilestoneModel.fromJson(m))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      selectedLawyerId: selLawyerId.isNotEmpty ? selLawyerId : null,
      selectedLawyerName: selLawyerData['fullName'],
      selectedLawyerImage: selLawyerData['profileImage'],
      selectedLawyerSpecialization: selLawyerProfile['specialization'],
      selectedLawyerExperience: selLawyerProfile['experience'],
      selectedLawyerRating: (selLawyerProfile['rating'] as num?)?.toDouble(),
      selectedLawyerFee: selLawyerProfile['consultationFee'],
      selectedLawyerVerified: selLawyerData['isVerified'] ?? false,
      assignedLawyerSpecialization: assignedLawyerProfile['specialization'],
      assignedLawyerExperience: assignedLawyerProfile['experience'],
      assignedLawyerRating: (assignedLawyerProfile['rating'] as num?)?.toDouble(),
      assignedLawyerFee: assignedLawyerProfile['consultationFee'],
      assignedLawyerVerified: lawyerData['isVerified'] ?? false,
      assignedLawyerOnline: lawyerData['isActive'] ?? true,
      caseOutcome: json['caseOutcome'] ?? '',
      claimAmount: json['claimAmount'] ?? '',
      consultationDate: json['consultationDate'] != null ? DateTime.parse(json['consultationDate']) : null,
      nextHearing: json['nextHearing'] != null ? DateTime.parse(json['nextHearing']) : null,
      closedDate: json['closedDate'] != null ? DateTime.parse(json['closedDate']) : null,
      acceptedAt: json['acceptedAt'] != null ? DateTime.parse(json['acceptedAt']) : null,
      startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt']) : null,
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      review: json['review'] ?? '',
      voiceUrl: json['voiceUrl'],
      voiceTranscript: json['voiceTranscript'],
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
    final lawyerData = json['lawyer'] is Map<String, dynamic> ? json['lawyer'] : {};
    final lId = json['lawyer'] is String ? json['lawyer'] : (lawyerData['_id'] ?? '');

    return CaseProposalModel(
      lawyerId: lId,
      fullName: lawyerData['fullName'] ?? 'Lawyer',
      profileImage: lawyerData['profileImage'] ?? '',
      feeProposal: json['feeProposal'] ?? 0,
      message: json['message'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
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
    return MilestoneModel(
      title: json['title'] ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      isCompleted: json['isCompleted'] ?? false,
    );
  }
}
