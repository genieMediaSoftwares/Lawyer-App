import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/calendar_provider.dart';

/// Calendar month/year header with left/right chevron navigation.
/// Matches the reference exactly:
/// - Left chevron flush left
/// - "May 2025" centered, bold, navy (#0B1F4D), 16px
/// - Right chevron flush right
class CalendarHeader extends ConsumerWidget {
  const CalendarHeader({super.key});

  static const _navy = Color(0xFF0B1F4D);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusedMonth = ref.watch(focusedMonthProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left chevron
          GestureDetector(
            onTap: () {
              ref.read(focusedMonthProvider.notifier).state = DateTime(
                focusedMonth.year,
                focusedMonth.month - 1,
                1,
              );
            },
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.chevron_left, color: _navy, size: 26),
            ),
          ),
          // Month Year title
          Text(
            DateFormat('MMMM yyyy').format(focusedMonth),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _navy,
              letterSpacing: 0.1,
            ),
          ),
          // Right chevron
          GestureDetector(
            onTap: () {
              ref.read(focusedMonthProvider.notifier).state = DateTime(
                focusedMonth.year,
                focusedMonth.month + 1,
                1,
              );
            },
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.chevron_right, color: _navy, size: 26),
            ),
          ),
        ],
      ),
    );
  }
}
