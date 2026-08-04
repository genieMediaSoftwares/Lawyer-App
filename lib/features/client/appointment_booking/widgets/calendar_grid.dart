import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/calendar_provider.dart';
import 'calendar_day_cell.dart';
import '../../../../core/theme/app_colors.dart';

/// Calendar date grid — localized weekday labels + 7-column date cells.
class CalendarGrid extends ConsumerWidget {
  final bool disablePastDates;
  final String? lawyerUserId;

  const CalendarGrid({
    super.key,
    this.disablePastDates = false,
    this.lawyerUserId,
  });

  List<String> _getLocalizedWeekdays(String localeCode) {
    // 2026-01-04 is a Sunday
    final baseSunday = DateTime(2026, 1, 4);
    final formatter = DateFormat.E(localeCode);
    return List.generate(7, (i) {
      final day = baseSunday.add(Duration(days: i));
      return formatter.format(day);
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusedMonth = ref.watch(focusedMonthProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final appointmentsState = ref.watch(calendarAppointmentsProvider);
    final localeCode = Localizations.localeOf(context).languageCode;
    final weekdays = _getLocalizedWeekdays(localeCode);

    final year = focusedMonth.year;
    final month = focusedMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // weekday: 1=Mon..7=Sun in Dart. We need Sunday=0 offset.
    final firstWeekdayOffset = DateTime(year, month, 1).weekday % 7;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Build list of week rows
    final List<TableRow> rows = [];

    // --- Localized Weekday header row ---
    rows.add(
      TableRow(
        children: weekdays.map((label) {
          return SizedBox(
            height: 32,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mutedText,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );

    // --- Date rows ---
    final totalSlots = firstWeekdayOffset + daysInMonth;
    final totalRows = (totalSlots / 7).ceil();

    // Get appointment dates for event dots
    final appointmentDays = <int>{};
    appointmentsState.whenData((appointments) {
      for (final appt in appointments) {
        if (lawyerUserId != null && appt.lawyerId != lawyerUserId) continue;
        if (appt.date.month == month &&
            appt.date.year == year &&
            appt.status != 'cancelled') {
          appointmentDays.add(appt.date.day);
        }
      }
    });

    for (int row = 0; row < totalRows; row++) {
      final cells = <Widget>[];
      for (int col = 0; col < 7; col++) {
        final index = row * 7 + col;
        if (index < firstWeekdayOffset || index >= totalSlots) {
          // Empty cell
          cells.add(const SizedBox(height: 48));
        } else {
          final dayNum = index - firstWeekdayOffset + 1;
          final cellDate = DateTime(year, month, dayNum);

          final isSelected =
              selectedDate.day == dayNum &&
              selectedDate.month == month &&
              selectedDate.year == year;

          final isToday = cellDate.isAtSameMomentAs(today);
          final isPast = cellDate.isBefore(today);
          final isDisabled = disablePastDates && isPast;
          final hasEvents = appointmentDays.contains(dayNum);

          cells.add(
            SizedBox(
              height: 48,
              child: CalendarDayCell(
                day: dayNum,
                isSelected: isSelected,
                isToday: isToday,
                hasEvents: hasEvents,
                isDisabled: isDisabled,
                onTap: () {
                  ref.read(selectedDateProvider.notifier).state = cellDate;
                },
              ),
            ),
          );
        }
      }
      rows.add(TableRow(children: cells));
    }

    return Table(defaultColumnWidth: const FlexColumnWidth(1), children: rows);
  }
}
