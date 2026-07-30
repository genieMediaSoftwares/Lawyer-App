class AISmartCaseAnalysis {
  final String caseTitle;
  final String caseDescription;
  final String category;
  final String priority;
  final String documentType;
  final String applicableLegalDomain;
  final List<String> requiredSupportingDocuments;
  final int aiConfidenceScore;
  final int readinessScore;
  final List<String> detectedTimeline;
  final String lawyerSpecializationRequired;
  final List<String> missingInformation;
  final List<String> followUpQuestions;
  final List<String> fraudFlags;

  AISmartCaseAnalysis({
    required this.caseTitle,
    required this.caseDescription,
    required this.category,
    required this.priority,
    required this.documentType,
    required this.applicableLegalDomain,
    required this.requiredSupportingDocuments,
    required this.aiConfidenceScore,
    required this.readinessScore,
    required this.detectedTimeline,
    required this.lawyerSpecializationRequired,
    required this.missingInformation,
    required this.followUpQuestions,
    required this.fraudFlags,
  });

  factory AISmartCaseAnalysis.fromJson(Map<String, dynamic> json) {
    return AISmartCaseAnalysis(
      caseTitle: json['caseTitle'] ?? '',
      caseDescription: json['caseDescription'] ?? '',
      category: json['category'] ?? 'General Legal',
      priority: json['priority'] ?? 'Medium',
      documentType: json['documentType'] ?? 'Document',
      applicableLegalDomain: json['applicableLegalDomain'] ?? '',
      requiredSupportingDocuments: List<String>.from(json['requiredSupportingDocuments'] ?? []),
      // Default to 0, not 80/85. An empty or malformed response used to render
      // as "85% ready", telling the client the analysis had gone well when
      // nothing had actually come back.
      aiConfidenceScore: (json['aiConfidenceScore'] as num?)?.toInt() ?? 0,
      readinessScore: (json['readinessScore'] as num?)?.toInt() ?? 0,
      detectedTimeline: List<String>.from(json['detectedTimeline'] ?? []),
      lawyerSpecializationRequired: json['lawyerSpecializationRequired'] ?? '',
      missingInformation: List<String>.from(json['missingInformation'] ?? []),
      followUpQuestions: List<String>.from(json['followUpQuestions'] ?? []),
      fraudFlags: List<String>.from(json['fraudFlags'] ?? []),
    );
  }
}

class DuplicateCheckResult {
  final bool isDuplicate;
  final String? existingCaseId;
  final String? existingCaseTitle;
  final int similarityScore;

  DuplicateCheckResult({
    required this.isDuplicate,
    this.existingCaseId,
    this.existingCaseTitle,
    required this.similarityScore,
  });

  factory DuplicateCheckResult.fromJson(Map<String, dynamic> json) {
    return DuplicateCheckResult(
      isDuplicate: json['isDuplicate'] == true,
      existingCaseId: json['existingCaseId']?.toString(),
      existingCaseTitle: json['existingCaseTitle']?.toString(),
      similarityScore: (json['similarityScore'] as num?)?.toInt() ?? 0,
    );
  }
}

class RecommendedLawyer {
  final String lawyerId;
  final String userId;
  final String name;
  final String email;
  final String avatar;
  final String specialization;

  /// Null means "not recorded for this lawyer", which is different from zero.
  /// These were previously defaulted to flattering values (4.8 rating, 88% win
  /// rate, 90 cases) whenever the database had nothing — presenting invented
  /// credentials to a client choosing legal representation. Render null as
  /// "New" or omit the metric; never substitute a number.
  final int? experience;
  final double? rating;
  final int totalReviews;
  final double? consultationFee;
  final double? winPercentage;
  final int casesHandled;
  final String officeAddress;
  final bool isVerified;

  RecommendedLawyer({
    required this.lawyerId,
    required this.userId,
    required this.name,
    required this.email,
    required this.avatar,
    required this.specialization,
    required this.experience,
    required this.rating,
    required this.totalReviews,
    required this.consultationFee,
    required this.winPercentage,
    required this.casesHandled,
    required this.officeAddress,
    required this.isVerified,
  });

  factory RecommendedLawyer.fromJson(Map<String, dynamic> json) {
    return RecommendedLawyer(
      lawyerId: json['lawyerId'] ?? json['_id'] ?? '',
      userId: json['userId'] ?? '',
      name: json['name'] ?? 'Advocate',
      email: json['email'] ?? '',
      avatar: json['avatar'] ?? '',
      specialization: json['specialization'] ?? '',
      // Absent stays absent — see the field docs above.
      experience: (json['experience'] as num?)?.toInt(),
      rating: (json['rating'] as num?)?.toDouble(),
      totalReviews: (json['totalReviews'] as num?)?.toInt() ?? 0,
      consultationFee: (json['consultationFee'] as num?)?.toDouble(),
      winPercentage: (json['winPercentage'] as num?)?.toDouble(),
      casesHandled: (json['casesHandled'] as num?)?.toInt() ?? 0,
      officeAddress: json['officeAddress'] ?? '',
      isVerified: json['isVerified'] == true,
    );
  }
}

class AISmartCaseSessionResponse {
  final String sessionId;
  final String status;
  final AISmartCaseAnalysis aiAnalysis;
  final DuplicateCheckResult duplicateCheck;
  final List<RecommendedLawyer> recommendedLawyers;
  final List<dynamic> uploadedDocuments;
  final String voiceTranscript;

  /// Documents whose text could not be extracted. The analysis did not see
  /// their contents, so the review screen must say so rather than implying
  /// everything was read.
  final List<ExtractionWarning> extractionWarnings;
  final bool voiceTranscriptionFailed;

  AISmartCaseSessionResponse({
    required this.sessionId,
    required this.status,
    required this.aiAnalysis,
    required this.duplicateCheck,
    required this.recommendedLawyers,
    required this.uploadedDocuments,
    required this.voiceTranscript,
    this.extractionWarnings = const [],
    this.voiceTranscriptionFailed = false,
  });

  factory AISmartCaseSessionResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return AISmartCaseSessionResponse(
      sessionId: data['sessionId'] ?? '',
      status: data['status'] ?? 'processing',
      aiAnalysis: AISmartCaseAnalysis.fromJson(data['aiAnalysis'] ?? {}),
      duplicateCheck: DuplicateCheckResult.fromJson(data['duplicateCheck'] ?? {}),
      recommendedLawyers: (data['recommendedLawyers'] as List? ?? [])
          .map((l) => RecommendedLawyer.fromJson(l))
          .toList(),
      uploadedDocuments: data['uploadedDocuments'] as List? ?? [],
      voiceTranscript: data['voiceTranscript'] ?? '',
      extractionWarnings: (data['extractionWarnings'] as List? ?? [])
          .map((w) => ExtractionWarning.fromJson(w as Map<String, dynamic>))
          .toList(),
      voiceTranscriptionFailed: data['voiceTranscriptionFailed'] == true,
    );
  }
}

/// A document the OCR pipeline could not read.
class ExtractionWarning {
  final String name;
  final String reason;

  ExtractionWarning({required this.name, required this.reason});

  factory ExtractionWarning.fromJson(Map<String, dynamic> json) {
    return ExtractionWarning(
      name: json['name'] ?? 'Document',
      reason: json['reason'] ?? 'Could not be read',
    );
  }
}
