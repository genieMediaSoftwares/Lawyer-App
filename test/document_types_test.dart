import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:law/core/config/app_config.dart';
import 'package:law/providers/document_provider.dart';

/// How a stored document becomes a choice of renderer.
///
/// The viewer decides what to draw from the document's type. That used to be
/// the stored MIME type alone — whatever the uploading device reported — so a
/// PDF that Android's file picker labelled `application/octet-stream` failed
/// every check and was shown as "cannot preview", or worse, spelled out as
/// text, while its name said `.pdf` the whole time.

DocumentRecord record({
  required String name,
  String mimeType = '',
  int fileSize = 1024,
}) =>
    DocumentRecord(
      id: 'doc-1',
      clientId: 'client-1',
      originalName: name,
      name: name,
      fileName: name,
      filePath: '/uploads/documents/$name',
      mimeType: mimeType,
      fileSize: fileSize,
      uploadedAt: DateTime(2026, 9, 17),
    );

void main() {
  group('Type detection', () {
    test('an honest MIME type is believed', () {
      expect(record(name: 'a.pdf', mimeType: 'application/pdf').isPdf, isTrue);
      expect(record(name: 'a.png', mimeType: 'image/png').isImage, isTrue);
      expect(record(name: 'a.txt', mimeType: 'text/plain').isText, isTrue);
    });

    test('octet-stream falls back to the extension', () {
      // Android's picker reports this for ordinary files.
      const generic = 'application/octet-stream';
      expect(record(name: 'brief.pdf', mimeType: generic).isPdf, isTrue);
      expect(record(name: 'scan.jpg', mimeType: generic).isImage, isTrue);
      expect(record(name: 'notes.txt', mimeType: generic).isText, isTrue);
      expect(
        record(name: 'petition.docx', mimeType: generic).canPreviewViaConversion,
        isTrue,
      );
    });

    test('an absent MIME type falls back to the extension', () {
      // Case attachments carry a name and nothing else.
      expect(record(name: 'order.pdf').isPdf, isTrue);
      expect(record(name: 'photo.jpeg').isImage, isTrue);
      expect(record(name: 'statement.csv').isText, isTrue);
    });

    test('a stored type wins over a misleading name', () {
      // The server knows what it stored; the extension is only a fallback.
      expect(
        record(name: 'invoice.pdf', mimeType: 'image/png').isImage,
        isTrue,
      );
      expect(record(name: 'invoice.pdf', mimeType: 'image/png').isPdf, isFalse);
    });

    test('an unknown type is viewable by no route', () {
      final unknown = record(name: 'archive.zip', mimeType: 'application/zip');
      expect(unknown.isPdf, isFalse);
      expect(unknown.isImage, isFalse);
      // The important one: NOT text. Rendering a zip as text fills the screen
      // with mojibake, which is what the viewer used to do for anything that
      // was not a PDF or an image.
      expect(unknown.isText, isFalse);
      expect(unknown.isViewable, isFalse);
    });

    test('legacy .doc is not mistaken for .docx', () {
      // The backend deliberately refuses the pre-2007 binary format; there is
      // no converter for it, so it must not claim a preview route.
      final doc = record(name: 'old.doc', mimeType: 'application/msword');
      expect(doc.canPreviewViaConversion, isFalse);
      expect(doc.isText, isFalse);
      expect(doc.isViewable, isFalse);
    });

    test('a name with no extension does not crash', () {
      final bare = record(name: 'scanned-document');
      expect(bare.isViewable, isFalse);
      expect(bare.extensionLabel, 'FILE');
    });

    test('extension matching ignores case', () {
      expect(record(name: 'SCAN.PDF').isPdf, isTrue);
      expect(record(name: 'Photo.JPG').isImage, isTrue);
    });
  });

  group('Text decoding', () {
    // The viewer decodes with utf8.decode, not String.fromCharCodes. The
    // latter reads each BYTE as a code unit, so it is only correct for ASCII —
    // and this app takes case descriptions in Telugu and Hindi.
    test('Telugu survives the round trip', () {
      const original = 'కేసు వివరణ: ఆస్తి వివాదం';
      expect(utf8.decode(utf8.encode(original), allowMalformed: true), original);
      expect(String.fromCharCodes(utf8.encode(original)), isNot(original));
    });

    test('Hindi survives the round trip', () {
      const original = 'मामले का विवरण';
      expect(utf8.decode(utf8.encode(original), allowMalformed: true), original);
    });

    test('an English document with a rupee sign survives', () {
      const original = 'Claim value: ₹1,50,000 — filed 17 Sep 2026';
      expect(utf8.decode(utf8.encode(original), allowMalformed: true), original);
      expect(String.fromCharCodes(utf8.encode(original)), isNot(original));
    });

    test('bytes that are not valid UTF-8 render instead of throwing', () {
      // A Windows-1252 export, say: mostly readable, so show it.
      final malformed = <int>[72, 101, 108, 108, 111, 0xFF, 0xFE];
      expect(
        () => utf8.decode(malformed, allowMalformed: true),
        returnsNormally,
      );
      expect(utf8.decode(malformed, allowMalformed: true), startsWith('Hello'));
    });
  });

  group('Picker extensions', () {
    test('offers only what the backend accepts', () {
      final offered = AppConfig.documentPickerExtensions;

      // `.doc` is deliberately refused server-side — a pre-2007 binary format
      // with no text extractor. Offering it produced uploads that always
      // failed.
      expect(offered, isNot(contains('doc')));

      // These the backend accepts and the viewer can display, but the
      // hardcoded list omitted them, so a plain text file could not be added
      // through the UI at all.
      expect(offered, contains('txt'));
      expect(offered, contains('docx'));
      expect(offered, contains('pdf'));
      expect(offered, containsAll(<String>['jpg', 'jpeg', 'png']));
    });

    test('every offered extension maps to a known type', () {
      for (final ext in AppConfig.documentPickerExtensions) {
        expect(
          DocumentRecord.mimeTypeForName('file.$ext'),
          isNotEmpty,
          reason: '.$ext is offered but has no type mapping',
        );
      }
    });
  });
}
