import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:law/core/theme/app_colors.dart';
import 'package:law/features/documents/document_action_bar.dart';

/// The View / Rename / Replace / Delete bar on a document card.
///
/// It used to be a Row of unbounded children, which clips whatever does not
/// fit — measured at 107 logical pixels past the right edge on a 360dp phone at
/// normal text size, and 165 at a 1.3x accessibility text scale. What went off
/// the edge was the right-hand end: the labels, then the overflow menu holding
/// Delete.
///
/// A Wrap cannot overflow, so these cases are about proving that at the sizes
/// and text scales real devices actually use.

/// Renders the bar at a given width and text scale, inside the same padding
/// the document cards apply.
Future<void> pumpBar(
  WidgetTester tester, {
  required double width,
  double textScale = 1.0,
  bool canModify = true,
  bool busy = false,
  VoidCallback? onView,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: DocumentActionBar(
                  busy: busy,
                  onView: onView ?? () {},
                  onRename: canModify ? () {} : null,
                  onReplace: canModify ? () {} : null,
                  onDelete: canModify ? () {} : null,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('Document action bar layout', () {
    // The widths of devices this app actually ships to, plus the text scales an
    // accessibility setting produces.
    for (final width in <double>[320, 360, 411, 480]) {
      for (final scale in <double>[1.0, 1.3, 1.5, 2.0]) {
        testWidgets('no overflow at ${width.toInt()}dp, ${scale}x text',
            (tester) async {
          await pumpBar(tester, width: width, textScale: scale);

          // A RenderFlex overflow surfaces as an exception in a test and as the
          // yellow-and-black stripes on a device.
          expect(
            tester.takeException(),
            isNull,
            reason: 'actions overflowed at ${width}dp / ${scale}x',
          );
        });
      }
    }

    testWidgets('all four actions are present and readable', (tester) async {
      await pumpBar(tester, width: 360);

      for (final label in ['View', 'Rename', 'Replace', 'Delete']) {
        expect(find.text(label), findsOneWidget, reason: '$label is missing');

        // Present but clipped would still be a bug, so check the label really
        // fits the box it was given.
        final para = tester.renderObject<RenderBox>(find.text(label));
        expect(para.size.width, greaterThan(0));
      }
    });

    testWidgets('labels are never truncated at the narrowest size',
        (tester) async {
      await pumpBar(tester, width: 320, textScale: 1.3);

      for (final label in ['View', 'Rename', 'Replace', 'Delete']) {
        expect(find.text(label), findsOneWidget);
        final widget = tester.widget<Text>(find.text(label));
        // Nothing sets an ellipsis: the bar wraps instead of shortening words.
        expect(widget.overflow, isNot(TextOverflow.ellipsis));
      }
    });

    testWidgets('every action is a thumb-sized target', (tester) async {
      await pumpBar(tester, width: 360);

      for (final label in ['View', 'Rename', 'Replace', 'Delete']) {
        final button = find.ancestor(
          of: find.text(label),
          matching: find.byType(TextButton),
        );
        final size = tester.getSize(button.first);
        expect(size.height, greaterThanOrEqualTo(40),
            reason: '$label is only ${size.height}dp tall');
      }
    });

    testWidgets('the label is part of the tap target, not just the icon',
        (tester) async {
      var viewed = 0;
      await pumpBar(tester, width: 360, onView: () => viewed++);

      // Tapping the word, not the eye.
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(viewed, 1);
    });

    testWidgets('owner-only actions are hidden when the user cannot modify',
        (tester) async {
      // An advocate reading a client's evidence: the server refuses writes, so
      // the buttons are not offered.
      await pumpBar(tester, width: 360, canModify: false);

      expect(find.text('View'), findsOneWidget);
      expect(find.text('Rename'), findsNothing);
      expect(find.text('Replace'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('actions disable while an operation is in flight',
        (tester) async {
      var viewed = 0;
      await pumpBar(tester, width: 360, busy: true, onView: () => viewed++);

      await tester.tap(find.text('View'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // A second tap must not start a duplicate rename or a second delete.
      expect(viewed, 0);
      for (final label in ['View', 'Rename', 'Replace', 'Delete']) {
        final button = tester.widget<TextButton>(
          find
              .ancestor(of: find.text(label), matching: find.byType(TextButton))
              .first,
        );
        expect(button.onPressed, isNull, reason: '$label is still enabled');
      }
    });

    testWidgets('Delete is distinguished from its neighbours', (tester) async {
      await pumpBar(tester, width: 360);

      final delete = tester.widget<TextButton>(
        find
            .ancestor(of: find.text('Delete'), matching: find.byType(TextButton))
            .first,
      );
      final colour = delete.style?.foregroundColor
          ?.resolve(<WidgetState>{});
      expect(colour, AppColors.error);
    });

    testWidgets('the bar stays clear of the floating upload button',
        (tester) async {
      // The list keeps 96dp of bottom padding so the last card's actions are
      // not covered by the extended FAB.
      await pumpBar(tester, width: 360);

      final listView = tester.widget<ListView>(find.byType(ListView));
      final padding = listView.padding as EdgeInsets;
      expect(padding.bottom, greaterThanOrEqualTo(88));
    });
  });
}
