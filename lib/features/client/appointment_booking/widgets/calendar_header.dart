import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/calendar_provider.dart';
import '../../../../core/theme/app_colors.dart';

/// Calendar month/year header with left/right chevron navigation.
class CalendarHeader extends ConsumerWidget {
  const CalendarHeader({super.key});

  static const _navy = AppColors.calendarAccent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusedMonth = ref.watch(focusedMonthProvider);
    final localeCode = Localizations.localeOf(context).languageCode;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
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
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Icon(Icons.chevron_left, color: _navy, size: 24),
            ),
          ),
          // Month Year title formatted according to current locale
          Text(
            DateFormat('MMMM yyyy', localeCode).format(focusedMonth),
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
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Icon(Icons.chevron_right, color: _navy, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}
