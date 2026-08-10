import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:law/core/localization/app_localizations.dart';
import 'package:law/features/client/case_tracking/screens/my_cases_screen.dart';
import 'package:law/models/case_model.dart';
import 'package:law/providers/case_provider.dart';
import 'package:law/providers/notification_provider.dart';

/// Renders My Cases at every Android size the app supports, and at the text
/// scales an accessibility setting can impose, asserting nothing overflows and
/// nothing is clipped.
///
/// A RenderFlex overflow is reported through FlutterError, which the test
/// binding surfaces via `tester.takeException()` — so "no yellow-and-black
/// stripes on a small phone" is assertable rather than something to eyeball on
/// a device.
///
/// The screen's own regression was quieter than an overflow: a fixed [TabBar]
/// gives each tab exactly a third of the width and `Tab(text:)` neither wraps
/// nor ellipsises, so "In Progress (3)" was silently painted past its edge and
/// cut off. Clipping raises no exception at all, which is why the tab labels
/// are measured against their slot below.
void main() {
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

  group('My Cases layout', () {
    for (final entry in sizes.entries) {
      for (final scale in textScales) {
        testWidgets('${entry.key} @ ${scale}x text does not overflow', (
          tester,
        ) async {
          await _pumpMyCases(tester, size: entry.value, textScale: scale);

          expect(
            tester.takeException(),
            isNull,
            reason: 'layout overflowed at ${entry.key} with ${scale}x text',
          );
        });
      }
    }

    for (final entry in sizes.entries) {
      testWidgets('tab labels fit their slot on a ${entry.key}', (
        tester,
      ) async {
        await _pumpMyCases(tester, size: entry.value, textScale: 1.3);

        // Three tabs share the bar evenly.
        final slot = tester.getSize(find.byType(TabBar)).width / 3;

        for (final label in const ['All Cases', 'In Progress', 'Closed']) {
          final finder = find.descendant(
            of: find.byType(TabBar),
            matching: find.textContaining(label),
          );
          expect(finder, findsOneWidget, reason: 'missing the "$label" tab');

          // `Tab(text:)` builds a `softWrap: false` Text, which reports the
          // width it was *given* however long the string is and quietly paints
          // the rest past the edge — no exception, and a plain size check sees
          // nothing wrong. Comparing what the paragraph needs against what it
          // got is what actually catches the clipped ")" in "In Progress (3)".
          final paragraph = tester.renderObject<RenderParagraph>(finder);
          expect(
            paragraph.getMaxIntrinsicWidth(double.infinity),
            lessThanOrEqualTo(paragraph.size.width + 0.5),
            reason: '"$label" is being clipped inside its tab',
          );

          // And the painted result — after the FittedBox scale-down — has to
          // stay inside the tab's third of the bar.
          expect(
            tester.getRect(finder).width,
            lessThanOrEqualTo(slot),
            reason: '"$label" is wider than its third of the tab bar',
          );
        }
      });
    }

    testWidgets('a long title, location and status stay inside the card', (
      tester,
    ) async {
      await _pumpMyCases(
        tester,
        size: const Size(320, 640),
        textScale: 1.3,
        cases: [
          _case(
            id: 'long-one',
            title:
                'Ajay Kumar and Others vs. Ravi Kumar, Suresh Kumar and the '
                'Greater Visakhapatnam Municipal Corporation',
            category: 'Property & Land Acquisition Disputes',
            status: 'Awaiting Lawyer Acceptance',
            location:
                'Madhurawada, Visakhapatnam, Visakhapatnam Urban, Andhra Pradesh',
          ),
        ],
      );

      expect(tester.takeException(), isNull);

      // Nothing in the card may be painted outside it. The card is the
      // InkWell's own box, inset from the list by its padding.
      final card = tester.getRect(find.byType(InkWell).first);
      for (final text in const [
        'Awaiting Lawyer Acceptance',
        'Posted',
        'Resolved',
        'View Case Details',
      ]) {
        final rect = tester.getRect(find.text(text).first);
        expect(
          rect.left,
          greaterThanOrEqualTo(card.left),
          reason: '"$text" starts left of the card',
        );
        expect(
          rect.right,
          lessThanOrEqualTo(card.right),
          reason: '"$text" is painted past the right edge of the card',
        );
      }
    });

    testWidgets('every case scrolls clear of the docked + button', (
      tester,
    ) async {
      await _pumpMyCases(
        tester,
        size: const Size(360, 740),
        cases: List.generate(
          6,
          (i) => _case(id: 'c$i', title: 'Case Number $i'),
        ),
      );

      final list = find.byType(Scrollable).first;
      await tester.drag(list, const Offset(0, -4000));
      await tester.pumpAndSettle();

      expect(find.text('Case Number 5'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The list is scrolled to the end, so the trailing padding is what keeps
      // the last card's own content above the FAB's overhang into the body.
      final listBottom = tester.getRect(list).bottom;
      final lastAction = tester.getRect(find.text('View Case Details').last);
      expect(
        listBottom - lastAction.bottom,
        greaterThanOrEqualTo(_fabClearance),
        reason: 'the last card ends underneath the floating + button',
      );
    });

    testWidgets('the In Progress and Closed tabs lay out too', (tester) async {
      await _pumpMyCases(
        tester,
        size: const Size(320, 640),
        textScale: 1.3,
        cases: [
          _case(id: 'p', title: 'Ongoing Matter', status: 'In Progress'),
          _case(
            id: 'c',
            title: 'Settled Matter',
            status: 'Closed',
            rating: 4,
            review: 'Handled the whole matter promptly and kept me informed.',
          ),
        ],
      );

      // Scoped to the TabBar: "In Progress" and "Closed" are also case
      // statuses, so they appear on the cards too.
      Finder tab(String label) => find.descendant(
        of: find.byType(TabBar),
        matching: find.textContaining(label),
      );

      await tester.tap(tab('In Progress'));
      await tester.pumpAndSettle();
      expect(find.text('Current Progress'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(tab('Closed'));
      await tester.pumpAndSettle();
      expect(find.text('Rate & Review'), findsNothing);
      expect(find.text('Edit Review'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the empty state fits and stays clear of the + button', (
      tester,
    ) async {
      await _pumpMyCases(
        tester,
        size: const Size(320, 640),
        textScale: 1.3,
        cases: const [],
      );

      expect(find.text('Post Your First Case'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// How far the centre-docked FAB in `AppShell` reaches up into the body.
const double _fabClearance = 56 / 2 + 16;

Future<void> _pumpMyCases(
  WidgetTester tester, {
  required Size size,
  double textScale = 1.0,
  List<CaseModel>? cases,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final data = cases ?? _sampleCases();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        casesProvider.overrideWith((ref) => _StubCaseNotifier(ref, data)),
        notificationsProvider.overrideWith((ref) => _StubNotificationNotifier()),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const MyCasesScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Serves a fixed list without fetching. [CaseNotifier]'s constructor calls
/// `fetchCases`, so the override has to be the thing that no-ops — setting the
/// state afterwards is not enough on its own.
class _StubCaseNotifier extends CaseNotifier {
  _StubCaseNotifier(super.ref, List<CaseModel> cases) {
    state = AsyncValue.data(cases);
  }

  @override
  Future<void> fetchCases({bool silent = false}) async {}
}

/// `NotificationNotifier(null)` skips both the network and the socket: its
/// constructor only initialises when it has a user id.
class _StubNotificationNotifier extends NotificationNotifier {
  _StubNotificationNotifier() : super(null);
}

List<CaseModel> _sampleCases() => [
  _case(
    id: 'b0bb53aa',
    title: 'Ajay Kumar vs. Ravi Kumar',
    category: 'Property & Land',
    status: 'Awaiting Lawyer Acceptance',
    location: 'Visakhapatnam, Visakhapatnam Urban',
    lawyerName: 'savaan',
  ),
  _case(
    id: 'b0bac3ff',
    title: 'Divorce Petition of Priya Sharma against Rahul Sharma',
    category: 'Family & Divorce',
    status: 'Awaiting Lawyer Acceptance',
    location: 'Hyderabad, Telangana',
  ),
];

CaseModel _case({
  required String id,
  required String title,
  String category = 'Property & Land',
  String status = 'Awaiting Lawyer Acceptance',
  String location = 'Visakhapatnam, Andhra Pradesh',
  String? lawyerName,
  double? rating,
  String? review,
}) {
  return CaseModel(
    id: id,
    clientId: 'client-1',
    clientName: 'Client',
    clientImage: '',
    title: title,
    description: 'A description of the matter that is long enough to be real.',
    category: category,
    location: location,
    budgetRange: '₹10,000 - ₹25,000',
    urgency: 'Normal',
    status: status,
    documents: const [],
    proposals: const [],
    milestones: const [],
    createdAt: DateTime(2026, 8, 8),
    selectedLawyerId: lawyerName != null ? 'lawyer-1' : null,
    selectedLawyerName: lawyerName,
    selectedLawyerSpecialization: lawyerName != null ? 'General Practice' : null,
    selectedLawyerRating: lawyerName != null ? 0.0 : null,
    selectedLawyerVerified: false,
    rating: rating,
    review: review,
  );
}
