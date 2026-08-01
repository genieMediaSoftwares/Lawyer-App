import 'package:flutter_test/flutter_test.dart';

import 'package:law/features/client/ai_smart_case/models/ai_smart_case_models.dart';

/// Locks the wire contract between the backend AI pipeline and the client.
///
/// The payloads below are the exact shapes the server produces — verified
/// against `AiSmartCaseSession.toJSON()` and the `/ai` socket events. The
/// completion payload is deliberately identical whether it arrives over the
/// socket or from `GET /ai/smart-case/session/:id`, so both are parsed here by
/// the same factory.
void main() {
  group('AnalysisProgress', () {
    test('parses a real per-document progress event', () {
      final progress = AnalysisProgress.fromJson(const {
        'sessionId': 'abc123',
        'stage': 'ocr',
        'message': 'Read document 3 of 7 — fir_copy.pdf',
        'percent': 23,
        'current': 3,
        'total': 7,
      });

      expect(progress.stage, 'ocr');
      expect(progress.message, 'Read document 3 of 7 — fir_copy.pdf');
      expect(progress.percent, 23);
      expect(progress.current, 3);
      expect(progress.total, 7);
      expect(progress.isTerminal, isFalse);
    });

    test('a missing or partial payload does not invent progress', () {
      const progress = AnalysisProgress();
      expect(progress.percent, 0);
      expect(progress.stage, 'queued');
      expect(progress.current, isNull);

      final partial = AnalysisProgress.fromJson(const {'stage': 'extracting'});
      expect(partial.percent, 0);
      expect(partial.message, isEmpty);
    });

    test('recognises the terminal stages', () {
      expect(
        AnalysisProgress.fromJson(const {'stage': 'completed'}).isTerminal,
        isTrue,
      );
      expect(
        AnalysisProgress.fromJson(const {'stage': 'failed'}).isTerminal,
        isTrue,
      );
    });
  });

  group('ExtractionResult', () {
    /// Mirrors the server payload byte for byte, including a field the model
    /// scored below CONFIDENCE_FLOOR: the server has already blanked
    /// `incidentDate` and named it in `needsReview`.
    const payload = {
      'sessionId': '68a1f2c4e5b6a7d8c9e0f1a2',
      'extracted': {
        'title': 'Cheque bounce recovery',
        'description': 'A cheque was dishonoured.',
        'summary': 'Client seeks recovery on a dishonoured cheque.',
        'category': 'Banking & Financial',
        'categoryId': 'banking_financial',
        'subType': 'Cheque Bounce',
        'urgency': 'High',
        'city': 'Hyderabad',
        'state': 'Telangana',
        'incidentDate': null,
        'opposingParty': 'Sharma Traders',
        'parties': [
          {'name': 'Sharma Traders', 'role': 'Drawer'},
          {'name': 'Ramesh Kumar', 'role': 'Payee'},
        ],
        'claimAmount': 125000,
        'isCriminalLike': false,
        'confidence': {'title': 0.9, 'category': 0.93, 'incidentDate': 0.2},
        'needsReview': ['incidentDate'],
      },
      'uploadedDocuments': [
        {
          'documentId': '68a1f2c4e5b6a7d8c9e0f1b3',
          'originalName': 'fir_copy.pdf',
          'url': '/uploads/cases/1720000-abc.pdf',
          'mimeType': 'application/pdf',
          'size': 2048,
          'ocrQuality': 'Scanned OCR',
        },
        {
          'documentId': '68a1f2c4e5b6a7d8c9e0f1b4',
          'originalName': 'blurred.jpg',
          'url': '/uploads/cases/1720001-def.jpg',
          'mimeType': 'image/jpeg',
          'size': 900,
          'ocrQuality': 'Extraction Unavailable',
        },
      ],
      'voiceTranscript': 'The bank returned my cheque.',
      'voiceTranscriptionFailed': false,
      'extractionWarnings': ['blurred.jpg: OCR service unavailable'],
    };

    test('parses the completion payload', () {
      final result = ExtractionResult.fromJson(payload);

      expect(result.sessionId, '68a1f2c4e5b6a7d8c9e0f1a2');
      expect(result.extracted.title, 'Cheque bounce recovery');
      expect(result.extracted.summary, isNotEmpty);
      expect(result.extracted.categoryId, 'banking_financial');
      expect(result.extracted.claimAmount, 125000);
      expect(result.warnings, hasLength(1));
      expect(result.voiceTranscript, 'The bank returned my cheque.');
    });

    test('a low-confidence field arrives blank and flagged for review', () {
      final data = ExtractionResult.fromJson(payload).extracted;

      expect(data.incidentDate, isNull);
      expect(data.needsReview, contains('incidentDate'));
      expect(data.confidenceFor('incidentDate'), 0.2);
      expect(data.confidenceFor('category'), 0.93);
      // A field the model never scored has no confidence, not a default.
      expect(data.confidenceFor('opposingParty'), isNull);
    });

    test('parses every named party with its role', () {
      final parties = ExtractionResult.fromJson(payload).extracted.parties;

      expect(parties, hasLength(2));
      expect(parties.first.display, 'Sharma Traders (Drawer)');
      expect(
        const ExtractedParty(name: 'Unnamed Bank').display,
        'Unnamed Bank',
        reason: 'A party with no role shows its name alone.',
      );
    });

    test('exposes which documents could not be read', () {
      final docs = ExtractionResult.fromJson(payload).uploadedDocuments;

      expect(docs, hasLength(2));
      expect(docs.first.readFailed, isFalse);
      expect(docs.last.readFailed, isTrue);
      // The catalogue id is what lets the Post Case form treat these as
      // already attached instead of asking for them again.
      expect(docs.first.documentId, isNotEmpty);
    });

    test('accepts the REST envelope and the socket payload identically', () {
      final fromSocket = ExtractionResult.fromJson(payload);
      final fromRest = ExtractionResult.fromJson({'data': payload});

      expect(fromRest.sessionId, fromSocket.sessionId);
      expect(fromRest.extracted.title, fromSocket.extracted.title);
      expect(fromRest.uploadedDocuments.length,
          fromSocket.uploadedDocuments.length);
    });

    test('an empty extraction is reported as empty rather than pre-filled', () {
      final result = ExtractionResult.fromJson(const {
        'sessionId': 's1',
        'extracted': <String, dynamic>{},
      });

      expect(result.extracted.isEmpty, isTrue);
      expect(result.extracted.title, isEmpty);
      expect(result.extracted.category, isNull);
      expect(result.extracted.urgency, isNull);
      expect(result.extracted.incidentDate, isNull);
      expect(result.extracted.parties, isEmpty);
    });
  });
}
