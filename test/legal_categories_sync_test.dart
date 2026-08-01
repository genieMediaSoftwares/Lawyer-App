import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:law/models/category_item.dart';

/// Guards the one thing that broke the AI auto-fill: the backend told Gemini to
/// return categories the Flutter form could not select.
///
/// The app's taxonomy lives in `lib/models/category_item.dart` (it carries
/// IconData, so it has to be Dart). The backend needs the same taxonomy to build
/// the extraction prompt and to normalise what the model returns, so it keeps a
/// JSON copy at `backend/src/config/legalCategories.json`.
///
/// Two copies can drift — and they had, badly: only 2 of 12 backend categories
/// matched the app's 15 ("Property Law" vs "Property & Land", "Civil Law" vs
/// "Civil Cases", plus "General Legal"/"Rental & Tenancy" which were not
/// categories at all). Roughly 10 in 12 extractions therefore produced a
/// category the form silently ignored.
///
/// This test fails the moment they disagree again. If it fails after you edit
/// the Dart list, regenerate the JSON rather than hand-editing it.
void main() {
  test('backend legalCategories.json matches the Dart allCategories list', () {
    final file = File('backend/src/config/legalCategories.json');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'backend/src/config/legalCategories.json is missing — the AI '
          'prompt has no taxonomy to generate from.',
    );

    final backend = (jsonDecode(file.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();

    expect(
      backend.length,
      allCategories.length,
      reason: 'category count differs: backend has ${backend.length}, '
          'app has ${allCategories.length}',
    );

    for (var i = 0; i < allCategories.length; i++) {
      final app = allCategories[i];
      final be = backend[i];

      expect(be['id'], app.id, reason: 'id mismatch at index $i');
      expect(be['title'], app.title, reason: 'title mismatch for "${app.id}"');
      expect(be['slug'], app.slug, reason: 'slug mismatch for "${app.id}"');
      expect(
        (be['subTypes'] as List).cast<String>(),
        app.subcategories,
        reason: 'sub-types mismatch for "${app.id}"',
      );
    }
  });

  test('every category has a non-empty, unique id and at least one sub-type',
      () {
    final ids = <String>{};
    for (final c in allCategories) {
      expect(c.id, isNotEmpty);
      expect(c.title, isNotEmpty);
      expect(c.subcategories, isNotEmpty,
          reason: '"${c.id}" has no sub-types, so the AI cannot pick one');
      expect(ids.add(c.id), isTrue, reason: 'duplicate category id "${c.id}"');
    }
  });
}
