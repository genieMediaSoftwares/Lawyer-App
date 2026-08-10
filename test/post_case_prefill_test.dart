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

  // The Lawyers step asks for recommendations as it builds. `flutter_test_config`
  // answers that with an immediate 503 instead of a socket, but the request
  // still has to be allowed to settle: Dio holds a zero-duration timer for the
  // life of a request, and an unfinished one fails teardown with "a Timer is
  // still pending". This used to settle by accident — `DioClient.dio` threw on
  // first touch because dotenv was never loaded in tests, so the provider went
  // straight to an error state and no request existed at all.
  await tester.pump(Duration.zero);
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

      // Advocates are recommended on category + sub-type. Opening the Lawyers
      // step without them showed the client the recommendation endpoint's
      // "Category is required" error, so the form opens on step 1 instead.
      expect(find.text('Select Category'), findsOneWidget);
      expect(find.text('Recommended Lawyers'), findsNothing);
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

      // Half a classification is not enough to recommend on, and Submit would
      // later refuse without a sub-type — so step 1 again, not Lawyers.
      expect(find.text('Select Category'), findsOneWidget);
      expect(find.text('Recommended Lawyers'), findsNothing);
    },
  );

  testWidgets(
    'the AI prefill opens the Lawyers step, not Review',
    (tester) async {
      // The manual flow is Category → Details → Documents → Lawyers → Review,
      // and the AI intake only completes the first three. Landing anywhere
      // other than Lawyers — or making Review reachable before a lawyer is
      // chosen — is the regression this guards.
      const result = ExtractionResult(
        sessionId: 'session-4',
        extracted: ExtractedCaseData(
          category: 'Banking & Financial',
          categoryId: 'banking_financial',
          subType: 'Cheque Bounce',
        ),
      );

      await _pumpForm(tester, result);

      expect(find.text('Recommended Lawyers'), findsOneWidget);
      expect(find.text('Review Your Case'), findsNothing);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Submit Case'), findsNothing);
      expect(find.text('(Select a lawyer to continue)'), findsOneWidget);
    },
  );

  testWidgets(
    'the terms are accepted on Review, not on Details',
    (tester) async {
      // One Terms & Conditions in the workflow, on the last step before
      // Submit, reached by both flows. On the Details step — where it used to
      // live — the AI flow never passed through it, so Submit refused over a
      // box the client had never been shown.
      const result = ExtractionResult(
        sessionId: 'session-5',
        extracted: ExtractedCaseData(
          category: 'Banking & Financial',
          categoryId: 'banking_financial',
          subType: 'Cheque Bounce',
        ),
      );

      await _pumpForm(tester, result);

      const termsLabel = 'I agree to the Terms & Conditions and Privacy Policy';

      // Lawyers → Documents → Details: no checkbox on any step before Review.
      // Review itself cannot be reached from here without a lawyer, and the
      // recommendation list needs the network — so its copy of the checkbox is
      // covered on device, not in this test.
      await tester.tap(find.text('Back'));
      await tester.pump();
      expect(find.text(termsLabel), findsNothing);

      await tester.tap(find.text('Back'));
      await tester.pump();
      expect(find.text('Case Details'), findsOneWidget);
      expect(find.text(termsLabel), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
    },
  );
}
