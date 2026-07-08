import 'document_model.dart';

class CaseModel {
  final String id;
  final String clientId;
  final String clientName;
  final String clientImage;
  final String title;
  final String description;
  final String category;
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

  CaseModel({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.clientImage,
    required this.title,
    required this.description,
    required this.category,
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
  });

  factory CaseModel.fromJson(Map<String, dynamic> json) {
    final clientData = json['client'] is Map<String, dynamic> ? json['client'] : {};
    final cId = json['client'] is String ? json['client'] : (clientData['_id'] ?? '');

    final lawyerData = json['assignedLawyer'] is Map<String, dynamic> ? json['assignedLawyer'] : {};
    final lId = json['assignedLawyer'] is String ? json['assignedLawyer'] : (lawyerData['_id'] ?? '');

    return CaseModel(
      id: json['_id'] ?? '',
      clientId: cId,
      clientName: clientData['fullName'] ?? '',
      clientImage: clientData['profileImage'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
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
