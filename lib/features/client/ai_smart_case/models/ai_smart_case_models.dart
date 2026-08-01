/// Models for the AI Smart Case intake.
///
/// Every value here originates from the backend pipeline — OCR, voice
/// transcription or the extraction model. Nothing in this file invents,
/// defaults or interpolates a value: a field the AI could not determine
/// arrives empty and stays empty, and the Post Case form leaves the
/// corresponding input untouched for the client to fill.
library;

/// One named party the documents identified.
class ExtractedParty {
  final String name;
  final String role;

  const ExtractedParty({required this.name, this.role = ''});

  factory ExtractedParty.fromJson(Map<String, dynamic> json) {
    return ExtractedParty(
      name: (json['name'] ?? '').toString().trim(),
      role: (json['role'] ?? '').toString().trim(),
    );
  }

  /// "Sharma Traders (Drawer)", or just the name when no role was given.
  String get display => role.isEmpty ? name : '$name ($role)';
}

/// A live position in the backend pipeline.
///
/// Constructed only from an `analysis_progress` socket event or from a session
/// fetch. There is deliberately no client-side constructor that advances a
/// stage on its own — the previous implementation drove this from a
/// `Timer.periodic` and showed the user work that was not happening.
class AnalysisProgress {
  /// Backend stage id: queued, ocr, transcribing, extracting, classifying,
  /// completed, failed.
  final String stage;

  /// The line to show, already composed by the backend
  /// ("Read document 2 of 5 — fir_copy.pdf").
  final String message;

  /// 0-100, derived from real stage weights on the server.
  final int percent;

  /// Position within a repeated stage, when one applies.
  final int? current;
  final int? total;

  const AnalysisProgress({
    this.stage = 'queued',
    this.message = '',
    this.percent = 0,
    this.current,
    this.total,
  });

  bool get isTerminal => stage == 'completed' || stage == 'failed';

  factory AnalysisProgress.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) => v is num ? v.toInt() : null;

    return AnalysisProgress(
      stage: (json['stage'] ?? 'queued').toString(),
      message: (json['message'] ?? '').toString(),
      percent: asInt(json['percent']) ?? 0,
      current: asInt(json['current']),
      total: asInt(json['total']),
    );
  }
}

/// Field values extracted from the client's documents and voice note.
///
/// Every field is optional. An empty string or null means "the documents did
/// not say, or the model was not confident enough" — see [needsReview] — and
/// the form leaves that input blank rather than guessing.
class ExtractedCaseData {
  final String title;
  final String description;

  /// Neutral synopsis of the matter, shown read-only for review. Distinct from
  /// [description], which is what actually gets filed.
  final String summary;

  /// Exact app category title (e.g. "Criminal Law"), already normalised
  /// server-side against the real taxonomy, or null if nothing matched.
  final String? category;

  /// Stable category id (e.g. "criminal_law") for selecting in the form.
  final String? categoryId;

  /// A sub-type belonging to [category], or null.
  final String? subType;

  /// One of Urgent / High / Medium / Flexible, or null.
  final String? urgency;

  final String city;
  final String state;
  final String location;
  final String court;

  /// When the incident happened — not the filing date.
  final DateTime? incidentDate;

  /// The single main opposing party. [parties] carries everyone named.
  final String opposingParty;

  /// Every party the documents identified, with each one's role.
  final List<ExtractedParty> parties;

  /// Only populated for Criminal Law, Cyber Crime and Motor Accident Claims.
  final String firNumber;
  final String policeStation;
  final String bailDetails;

  final double? claimAmount;
  final String documentType;

  /// True when [category] is one of the three categories for which the FIR /
  /// police station / bail field group is relevant.
  final bool isCriminalLike;

  /// Per-field 0-1 confidence reported by the model.
  final Map<String, double> confidence;

  /// Fields the model filled but was not confident enough about. The server
  /// has already cleared their values; they are named here so the form can
  /// prompt the client to supply them.
  final List<String> needsReview;

  const ExtractedCaseData({
    this.title = '',
    this.description = '',
    this.summary = '',
    this.category,
    this.categoryId,
    this.subType,
    this.urgency,
    this.city = '',
    this.state = '',
    this.location = '',
    this.court = '',
    this.incidentDate,
    this.opposingParty = '',
    this.parties = const [],
    this.firNumber = '',
    this.policeStation = '',
    this.bailDetails = '',
    this.claimAmount,
    this.documentType = '',
    this.isCriminalLike = false,
    this.confidence = const {},
    this.needsReview = const [],
  });

  /// True when the extraction produced nothing worth pre-filling, so the caller
  /// can tell the client rather than opening a blank form that looks broken.
  bool get isEmpty =>
      title.isEmpty &&
      description.isEmpty &&
      summary.isEmpty &&
      category == null &&
      city.isEmpty &&
      location.isEmpty &&
      opposingParty.isEmpty &&
      parties.isEmpty &&
      incidentDate == null;

  /// Confidence for [field], or null when the model did not score it.
  double? confidenceFor(String field) => confidence[field];

  static String _str(dynamic v) => (v ?? '').toString().trim();

  static String? _nullable(dynamic v) {
    final s = _str(v);
    return s.isEmpty ? null : s;
  }

  factory ExtractedCaseData.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      final s = _str(v);
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    final rawConfidence = json['confidence'];
    final confidence = <String, double>{};
    if (rawConfidence is Map) {
      rawConfidence.forEach((key, value) {
        final score = value is num ? value.toDouble() : double.tryParse('$value');
        if (score != null) confidence[key.toString()] = score;
      });
    }

    final rawParties = json['parties'];
    final parties = <ExtractedParty>[];
    if (rawParties is List) {
      for (final entry in rawParties) {
        if (entry is Map) {
          final party = ExtractedParty.fromJson(Map<String, dynamic>.from(entry));
          if (party.name.isNotEmpty) parties.add(party);
        }
      }
    }

    return ExtractedCaseData(
      title: _str(json['title']),
      description: _str(json['description']),
      summary: _str(json['summary']),
      category: _nullable(json['category']),
      categoryId: _nullable(json['categoryId']),
      subType: _nullable(json['subType']),
      urgency: _nullable(json['urgency']),
      city: _str(json['city']),
      state: _str(json['state']),
      location: _str(json['location']),
      court: _str(json['court']),
      incidentDate: parseDate(json['incidentDate']),
      opposingParty: _str(json['opposingParty']),
      parties: parties,
      firNumber: _str(json['firNumber']),
      policeStation: _str(json['policeStation']),
      bailDetails: _str(json['bailDetails']),
      claimAmount: (json['claimAmount'] as num?)?.toDouble(),
      documentType: _str(json['documentType']),
      isCriminalLike: json['isCriminalLike'] == true,
      confidence: confidence,
      needsReview: (json['needsReview'] as List? ?? const [])
          .map((f) => f.toString())
          .where((f) => f.isNotEmpty)
          .toList(),
    );
  }
}

/// A document the client uploaded during the AI intake.
///
/// [documentId] is the id of the record in the same `Document` collection the
/// manual Post Case upload writes to, which is what lets the form treat these
/// as already attached instead of asking for them again.
class AnalyzedDocument {
  final String documentId;
  final String originalName;
  final String url;
  final String mimeType;
  final int size;

  /// The pipeline's verdict on how well this document read: Good,
  /// Scanned OCR, Low Confidence, or Extraction Unavailable.
  final String ocrQuality;

  const AnalyzedDocument({
    this.documentId = '',
    this.originalName = '',
    this.url = '',
    this.mimeType = '',
    this.size = 0,
    this.ocrQuality = '',
  });

  bool get readFailed => ocrQuality == 'Extraction Unavailable';

  factory AnalyzedDocument.fromJson(Map<String, dynamic> json) {
    return AnalyzedDocument(
      documentId: (json['documentId'] ?? '').toString(),
      originalName: (json['originalName'] ?? json['name'] ?? '').toString(),
      url: (json['url'] ?? json['filePath'] ?? '').toString(),
      mimeType: (json['mimeType'] ?? '').toString(),
      size: (json['size'] as num?)?.toInt() ?? 0,
      ocrQuality: (json['ocrQuality'] ?? '').toString(),
    );
  }
}

/// The finished result of one intake run.
///
/// Built from either the `analysis_complete` socket event or a
/// `GET /ai/smart-case/session/:id` response — the backend deliberately gives
/// both the same shape so there is one parser and one source of truth.
class ExtractionResult {
  final String sessionId;
  final ExtractedCaseData extracted;

  /// Documents whose text could not be read, plus any server-side coercion
  /// notes. Shown on the form so it says what the extraction did not cover
  /// instead of implying it read everything.
  final List<String> warnings;

  final bool voiceTranscriptionFailed;

  /// Documents already uploaded and catalogued server-side.
  final List<AnalyzedDocument> uploadedDocuments;

  /// Whatever transcript the server ended up using.
  final String voiceTranscript;

  const ExtractionResult({
    required this.sessionId,
    required this.extracted,
    this.warnings = const [],
    this.voiceTranscriptionFailed = false,
    this.uploadedDocuments = const [],
    this.voiceTranscript = '',
  });

  factory ExtractionResult.fromJson(Map<String, dynamic> json) {
    // Accepts the socket payload, the flattened session response, and the
    // `{data: {...}}` envelope the REST layer wraps successes in.
    final data = (json['data'] is Map)
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;

    final rawDocs = data['uploadedDocuments'] as List? ?? const [];

    return ExtractionResult(
      sessionId: (data['sessionId'] ?? data['_id'] ?? '').toString(),
      extracted: ExtractedCaseData.fromJson(
        Map<String, dynamic>.from((data['extracted'] ?? const {}) as Map),
      ),
      warnings: (data['extractionWarnings'] as List? ?? const [])
          .map((w) => w.toString())
          .where((w) => w.isNotEmpty)
          .toList(),
      voiceTranscriptionFailed: data['voiceTranscriptionFailed'] == true,
      uploadedDocuments: rawDocs
          .whereType<Map>()
          .map((d) => AnalyzedDocument.fromJson(Map<String, dynamic>.from(d)))
          .toList(),
      voiceTranscript: (data['voiceTranscript'] ?? '').toString(),
    );
  }
}
