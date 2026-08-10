import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:law/features/client/ai_smart_case/models/ai_smart_case_models.dart';
import 'package:law/features/client/post_case/screens/post_case_screen.dart';
import 'package:law/models/lawyer_model.dart';
import 'package:law/providers/lawyer_provider.dart';

/// Covers the Post Your Case → Lawyers step: the recommendation cards must lay
/// out cleanly at every Android size the app supports, and the whole card — not
/// just its "Select Lawyer" button — must pick the advocate.
///
/// The card used to put the match percentage and response time in a third
/// column with no width constraint. A `Row` gives its non-flexible children
/// unbounded main-axis space, so that column took whatever it wanted and the
/// `Expanded` middle column was left with the remainder — on a 360dp phone that
/// was narrow enough to break "General Practice" into one word per line and
/// stack the experience/cases line vertically. Those stats now sit in a `Wrap`
/// below the details, where they reflow onto their own line instead of starving
/// the text beside them.
///
/// A RenderFlex overflow is reported through FlutterError, which the test
/// binding surfaces via `tester.takeException()`, so "nothing overflows on a
/// small phone" is assertable rather than something to eyeball on a device.
void main() {
  // A tap that lands on nothing is normally only a warning, which would let a
  // "the card is selectable" test pass without ever hitting the card.
  WidgetController.hitTestWarningShouldBeFatal = true;

  // Logical sizes, smallest realistic phone upward.
  const sizes = <String, Size>{
    'small phone (320x640)': Size(320, 640),
    'compact phone (360x740)': Size(360, 740),
    'standard phone (411x890)': Size(411, 890),
    'large phone (480x1000)': Size(480, 1000),
    'tablet (768x1024)': Size(768, 1024),
  };

  // 1.0 is the default; 1.3 is a common accessibility bump and the case that
  // breaks layouts built around fixed-width text.
  const textScales = <double>[1.0, 1.3];

  group('Lawyers step layout', () {
    for (final entry in sizes.entries) {
      for (final scale in textScales) {
        testWidgets('${entry.key} @ ${scale}x text does not overflow', (
          tester,
        ) async {
          await _pumpLawyersStep(tester, size: entry.value, textScale: scale);

          expect(find.text('Recommended Lawyers'), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: 'layout overflowed at ${entry.key} with ${scale}x text',
          );
        });
      }
    }

    testWidgets('long names, practice areas and locations stay on one line', (
      tester,
    ) async {
      await _pumpLawyersStep(
        tester,
        size: const Size(320, 640),
        textScale: 1.3,
        lawyers: [
          _lawyer(
            id: 'long',
            fullName: 'Adv. Chandrasekharan Venkataraman Subramanian',
            specialization: 'Consumer Protection and Product Liability',
            location: 'Anna Nagar West Extension, Chennai, Tamil Nadu',
            responseTime: 'Responds within 2 hours',
          ),
        ],
      );

      expect(tester.takeException(), isNull);

      for (final text in const [
        'Adv. Chandrasekharan Venkataraman Subramanian',
        'Consumer Protection and Product Liability',
        'Anna Nagar West Extension, Chennai, Tamil Nadu',
      ]) {
        final widget = tester.widget<Text>(find.text(text));
        expect(
          widget.maxLines,
          1,
          reason: '"$text" must ellipsise, not wrap into a narrow column',
        );
        expect(widget.overflow, TextOverflow.ellipsis);
      }
    });

    testWidgets('every card is reachable by scrolling on a short screen', (
      tester,
    ) async {
      await _pumpLawyersStep(
        tester,
        size: const Size(360, 640),
        textScale: 1.0,
        lawyers: List.generate(
          5,
          (i) => _lawyer(id: 'l$i', fullName: 'Adv. Number $i'),
        ),
      );

      // The Back/Next bar is a sibling below the scroll view, so its top edge
      // is where the scrollable region ends — nothing scrollable may be drawn
      // past it.
      final navTop = tester
          .getRect(find.widgetWithText(OutlinedButton, 'Back'))
          .top;

      // Five cards are taller than the viewport, so the last one starts below
      // the fold and has to be scrolled to.
      expect(
        tester.getRect(find.text('Adv. Number 4')).top,
        greaterThan(navTop),
        reason: 'the fixture must be tall enough to require scrolling',
      );

      // `ensureVisible`, not `scrollUntilVisible`: the step has two scrollables
      // (this one and the horizontal filter chips) and only the target's own
      // ancestor should move.
      await tester.ensureVisible(find.text('Adv. Number 4'));
      await tester.pumpAndSettle();

      final lastCard = tester.getRect(find.text('Adv. Number 4'));
      expect(lastCard.top, greaterThanOrEqualTo(0));
      expect(
        lastCard.bottom,
        lessThanOrEqualTo(navTop),
        reason: 'the navigation bar must not cover a scrolled-to lawyer card',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the filter chips scroll horizontally', (tester) async {
      await _pumpLawyersStep(
        tester,
        size: const Size(320, 640),
        textScale: 1.0,
      );

      // "Fees: Low to High" is past the right edge of a 320dp screen and is
      // reached by scrolling the chip row, not by the row wrapping or clipping.
      final chipRow = find
          .ancestor(
            of: find.text('Best Match'),
            matching: find.byType(SingleChildScrollView),
          )
          .first;
      expect(
        tester.widget<SingleChildScrollView>(chipRow).scrollDirection,
        Axis.horizontal,
      );

      await tester.drag(chipRow, const Offset(-200, 0));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('Lawyer selection', () {
    testWidgets('tapping the card body selects the lawyer', (tester) async {
      await _pumpLawyersStep(tester, size: const Size(360, 740));

      expect(_selectedCount(tester), 0);
      expect(find.text('(Select a lawyer to continue)'), findsOneWidget);

      // Anywhere in the card: the name sits in the information area, well away
      // from either button.
      await _tapVisible(tester, find.text('Adv. Meera Krishnan'));

      expect(_selectedCount(tester), 1);
      expect(find.text('Selected'), findsOneWidget);
      expect(find.text('(Select a lawyer to continue)'), findsNothing);
      expect(_nextEnabled(tester), isTrue);
    });

    testWidgets('the Select Lawyer button runs the same selection', (
      tester,
    ) async {
      await _pumpLawyersStep(tester, size: const Size(360, 740));

      await _tapVisible(tester, find.text('Select Lawyer').first);

      expect(_selectedCount(tester), 1);
      expect(_nextEnabled(tester), isTrue);
    });

    testWidgets('tapping a selected card again clears the selection', (
      tester,
    ) async {
      await _pumpLawyersStep(tester, size: const Size(360, 740));

      await _tapVisible(tester, find.text('Adv. Meera Krishnan'));
      expect(_selectedCount(tester), 1);

      await _tapVisible(tester, find.text('Adv. Meera Krishnan'));

      expect(_selectedCount(tester), 0);
      expect(_nextEnabled(tester), isFalse);
    });

    testWidgets('only one lawyer can be selected at a time', (tester) async {
      await _pumpLawyersStep(tester, size: const Size(360, 740));

      await _tapVisible(tester, find.text('Adv. Meera Krishnan'));
      expect(_selectedCount(tester), 1);

      // The second card is below the fold, so scroll it in before tapping —
      // otherwise the tap silently misses and the assertion below passes for
      // the wrong reason.
      await _tapVisible(tester, find.text('Adv. Rohit Sharma'));

      expect(_selectedCount(tester), 1);
      expect(find.text('Selected'), findsOneWidget);
      // The tick must have moved to the second card, not stayed on the first.
      expect(
        tester.getRect(find.byIcon(Icons.check_circle)).top,
        greaterThan(tester.getRect(find.text('Adv. Meera Krishnan')).top),
      );
    });

    testWidgets('View Profile opens the sheet without selecting', (
      tester,
    ) async {
      await _pumpLawyersStep(tester, size: const Size(360, 740));

      await _tapVisible(tester, find.text('View Profile').first);
      await tester.pumpAndSettle();

      expect(find.text('Select This Lawyer'), findsOneWidget);
      expect(
        _selectedCount(tester),
        0,
        reason: 'the button must not fall through to the card tap handler',
      );
    });
  });
}

/// Scrolls a card's action button into the viewport before tapping it. The
/// buttons sit at the bottom of a tall card, so on a phone-sized viewport the
/// first card's row is already below the fold.
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

/// Number of cards showing the gold tick. Counts only the recommendation list's
/// indicator, which is the one selection state the step renders.
int _selectedCount(WidgetTester tester) =>
    find.byIcon(Icons.check_circle).evaluate().length;

bool _nextEnabled(WidgetTester tester) {
  final button = tester.widget<ElevatedButton>(
    find
        .ancestor(of: find.text('Next'), matching: find.byType(ElevatedButton))
        .first,
  );
  return button.onPressed != null;
}

/// Opens the form directly on the Lawyers step with a fixed recommendation
/// list. The AI prefill is the supported way in — it completes the first three
/// steps and lands on step 4 (see `post_case_prefill_test.dart`).
Future<void> _pumpLawyersStep(
  WidgetTester tester, {
  required Size size,
  double textScale = 1.0,
  List<LawyerModel>? lawyers,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  const prefill = ExtractionResult(
    sessionId: 'lawyers-step',
    extracted: ExtractedCaseData(
      title: 'Cheque dishonoured by Sharma Traders',
      category: 'Banking & Financial',
      categoryId: 'banking_financial',
      subType: 'Cheque Bounce',
    ),
  );

  final data = lawyers ?? _sampleLawyers();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        recommendedLawyersProvider.overrideWith((ref, _) async => data),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: const MaterialApp(home: PostCaseScreen(prefill: prefill)),
      ),
    ),
  );

  // The prefill commits its category after the first frame, then the (stubbed)
  // recommendation future resolves.
  await tester.pump();
  await tester.pump(Duration.zero);
}

List<LawyerModel> _sampleLawyers() => [
  _lawyer(
    id: 'meera',
    fullName: 'Adv. Meera Krishnan',
    specialization: 'General Practice',
    location: 'T. Nagar, Chennai',
  ),
  _lawyer(
    id: 'rohit',
    fullName: 'Adv. Rohit Sharma',
    specialization: 'Banking & Financial',
    location: 'Bandra East, Mumbai',
  ),
];

/// A lawyer with no profile image on purpose: `Image.network` cannot resolve in
/// a widget test, and the placeholder it falls back to occupies exactly the
/// same box, so the layout under test is unchanged.
LawyerModel _lawyer({
  required String id,
  required String fullName,
  String specialization = 'General Practice',
  String location = 'Chennai, Tamil Nadu',
  String responseTime = 'Responds within 2 hours',
}) {
  return LawyerModel(
    id: id,
    userId: 'user-$id',
    fullName: fullName,
    email: '$id@example.com',
    mobile: '9000000000',
    profileImage: '',
    specialization: specialization,
    experience: 12,
    education: 'LLB, National Law School',
    consultationFee: 1500,
    bio: 'Practising advocate.',
    rating: 4.6,
    totalReviews: 128,
    languages: const ['English', 'Hindi', 'Tamil', 'Telugu'],
    barCouncilNumber: 'TN/1234/2012',
    location: location,
    officeAddress: 'Office Suite, City Center',
    upiId: '',
    workingHours: '9:00 AM - 6:00 PM',
    bankDetails: const {},
    casesHandled: 120,
    winPercentage: 82,
    isVerified: true,
    responseTime: responseTime,
    matchPercentage: 65,
    onlineStatus: true,
  );
}
