import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:law/features/client/ai_smart_case/models/ai_smart_case_models.dart';
import 'package:law/features/client/post_case/screens/post_case_screen.dart';
import 'package:law/providers/category_provider.dart';

/// Covers the two rules the AI prefill has to obey.
///
/// 1. It must not write to [selectedCategoryProvider] from initState — Riverpod
///    rejects that while the tree is building ("Tried to modify a provider
///    while the widget tree was building"). The selection is committed after
///    the first frame instead.
///
/// 2. It must not invent a category. When the extraction could not classify the
///    matter, the dropdown stays empty so the client chooses. This used to fall
///    back to `_categories.first` plus its first sub-type, and because the case
///    title was derived from the sub-type, an unclassifiable document was filed
///    under a wrong category *and* a wrong title.
Future<void> _pumpForm(WidgetTester tester, ExtractionResult result) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: PostCaseScreen(prefill: result)),
    ),
  );
  expect(tester.takeException(), isNull);

  // The post-frame callback lands on the next pump.
  await tester.pump();
  expect(tester.takeException(), isNull);
}

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(PostCaseScreen)));

void main() {
  testWidgets(
    'an unclassified extraction selects no category and does not modify providers during build',
    (tester) async {
      // Mirrors a failed classification: the document yielded no category.
      const result = ExtractionResult(
        sessionId: 'session-1',
        extracted: ExtractedCaseData(documentType: 'Divorce Case Document'),
      );

      await _pumpForm(tester, result);

      final state = _containerOf(tester).read(selectedCategoryProvider);
      expect(
        state.categoryId,
        isNull,
        reason: 'No category was extracted, so none may be selected.',
      );
      expect(state.subcategory, isNull);
    },
  );

  testWidgets(
    'an extracted category and sub-type are selected after the first frame',
    (tester) async {
      const result = ExtractionResult(
        sessionId: 'session-2',
        extracted: ExtractedCaseData(
          title: 'Cheque dishonoured by Sharma Traders',
          category: 'Banking & Financial',
          categoryId: 'banking_financial',
          subType: 'Cheque Bounce',
        ),
      );

      await _pumpForm(tester, result);

      final state = _containerOf(tester).read(selectedCategoryProvider);
      expect(state.categoryId, 'banking_financial');
      expect(state.subcategory, 'Cheque Bounce');
    },
  );

  testWidgets(
    'a category without a matching sub-type selects the category only',
    (tester) async {
      // The extractor resolved the category but not a sub-type belonging to it.
      // Defaulting to `subcategories.first` would put a sub-type the documents
      // never mentioned onto the case.
      const result = ExtractionResult(
        sessionId: 'session-3',
        extracted: ExtractedCaseData(
          category: 'Banking & Financial',
          categoryId: 'banking_financial',
        ),
      );

      await _pumpForm(tester, result);

      final state = _containerOf(tester).read(selectedCategoryProvider);
      expect(state.categoryId, 'banking_financial');
      expect(
        state.subcategory,
        isNull,
        reason: 'No sub-type was extracted, so none may be guessed.',
      );
    },
  );
}
