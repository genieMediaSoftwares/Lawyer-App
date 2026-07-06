import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/calendar_provider.dart';
import 'calendar_day_cell.dart';

/// Calendar date grid — weekday labels + 7-column date cells.
/// Matches the reference exactly:
/// - Weekday row: Sun Mon Tue Wed Thu Fri Sat, grey (#7E8797), w500, 13px
/// - Date cells use Table layout for perfectly equal 7 columns
/// - Row height ~48px to match the reference spacing
class CalendarGrid extends ConsumerWidget {
  final bool disablePastDates;
  final String? lawyerUserId;

  const CalendarGrid({
    super.key,
    this.disablePastDates = false,
    this.lawyerUserId,
  });

  static const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusedMonth = ref.watch(focusedMonthProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final appointmentsState = ref.watch(calendarAppointmentsProvider);

    final year = focusedMonth.year;
    final month = focusedMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // weekday: 1=Mon..7=Sun in Dart. We need Sunday=0 offset.
    final firstWeekdayOffset = DateTime(year, month, 1).weekday % 7;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Build list of week rows
    final List<TableRow> rows = [];

    // --- Weekday header row ---
    rows.add(
      TableRow(
        children: _weekdays.map((label) {
          return SizedBox(
            height: 32,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF7E8797),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );

    // --- Date rows ---
    // Flatten all day slots into a single list: offset blanks + actual days
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

          final isSelected = selectedDate.day == dayNum &&
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

    return Table(
      defaultColumnWidth: const FlexColumnWidth(1),
      children: rows,
    );
  }
}
