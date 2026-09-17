import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:law/core/theme/app_colors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:law/core/theme/app_chip_theme.dart';

/// The Documents screen's All / PDF / DOC / Images row, and every other chip.
///
/// The chip you had selected was the one you could not read: the theme set
/// `labelStyle` to gold and `selectedColor` to the same gold, and in Material 3
/// a FilterChip takes its label colour from `labelStyle` in BOTH states — only
/// ChoiceChip consults `secondaryLabelStyle`, where the intended black was
/// parked. Selected text was therefore drawn in the background's own colour.
///
/// These pin the contrast rather than the colour values, so the palette can be
/// retuned without silently reintroducing an unreadable state.

/// WCAG 2.1 relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

/// WCAG 2.1 contrast ratio: 1.0 is invisible, 21.0 is black on white.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The colour the chip's label is actually painted in, as RawChip resolves it.
Color _labelColour(ThemeData theme, Set<WidgetState> states) {
  final style = theme.chipTheme.labelStyle!;
  final resolved = WidgetStateProperty.resolveAs<Color?>(style.color, states);
  expect(resolved, isNotNull, reason: 'the chip label must have a colour');
  return resolved!;
}

void main() {
  // The chip theme alone, not the whole ThemeData: AppTheme's text styles come
  // from google_fonts, which fetches a font over the network the moment it is
  // built. The chip's colours are what these tests are about, and they need no
  // typeface at all.
  ThemeData theme() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        chipTheme: AppChipTheme.chipTheme,
        scaffoldBackgroundColor: AppColors.primaryBackground,
      );

  group('Document filter chips', () {
    test('the selected chip label is readable on the selected background', () {
      final label = _labelColour(theme(), {WidgetState.selected});
      final background = theme().chipTheme.selectedColor!;

      // This was exactly 1.0 — the same colour on itself.
      expect(
        _contrast(label, background),
        greaterThanOrEqualTo(4.5),
        reason: 'selected chip label $label on $background',
      );
    });

    test('the unselected chip label is readable on the chip background', () {
      final label = _labelColour(theme(), <WidgetState>{});
      final background = theme().chipTheme.backgroundColor!;

      expect(
        _contrast(label, background),
        greaterThanOrEqualTo(4.5),
        reason: 'unselected chip label $label on $background',
      );
    });

    test('selected and unselected labels are not the same colour', () {
      // The defect in one line: one style serving two backgrounds.
      expect(
        _labelColour(theme(), {WidgetState.selected}),
        isNot(equals(_labelColour(theme(), <WidgetState>{}))),
      );
    });

    test('the chip border stays visible against the screen behind it', () {
      final shape = theme().chipTheme.shape! as RoundedRectangleBorder;
      expect(
        _contrast(shape.side.color, theme().scaffoldBackgroundColor),
        greaterThanOrEqualTo(3.0),
      );
    });

    testWidgets('a real selected FilterChip paints a readable label',
        (tester) async {
      // Guards the assumption the unit tests above rest on: that RawChip reads
      // `chipTheme.labelStyle` for a selected FilterChip and resolves a
      // WidgetStateColor against its states.
      await tester.pumpWidget(MaterialApp(
        theme: theme(),
        home: Scaffold(
          body: Row(
            children: [
              FilterChip(
                label: const Text('All'),
                selected: true,
                onSelected: (_) {},
              ),
              FilterChip(
                label: const Text('Images'),
                selected: false,
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      Color painted(String text) {
        final rich = tester.widget<RichText>(
          find.descendant(
            of: find.text(text),
            matching: find.byType(RichText),
            matchRoot: true,
          ),
        );
        return rich.text.style!.color!;
      }

      expect(
        _contrast(painted('All'), theme().chipTheme.selectedColor!),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(painted('Images'), theme().chipTheme.backgroundColor!),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets('"Images" is never truncated in the filter row', (tester) async {
      // The row scrolls horizontally rather than shrinking its chips, so the
      // longest label stays whole on the narrowest phone.
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: theme(),
        home: Scaffold(
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final label in ['All', 'PDF', 'DOC', 'Images', 'Text'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(label),
                      selected: label == 'All',
                      onSelected: (_) {},
                    ),
                  ),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final images = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.text('Images'),
          matching: find.byType(RichText),
          matchRoot: true,
        ),
      );
      expect(images.didExceedMaxLines, isFalse);
      expect(find.text('Images'), findsOneWidget);
    });
  });
}
