import 'package:flutter/material.dart';
import 'calendar_header.dart';
import 'calendar_grid.dart';

/// The calendar card container widget.
/// Matches the reference exactly:
/// - White background
/// - 20px border radius
/// - Very soft shadow (#00000010)
/// - 20px horizontal padding, 16px vertical padding
class CalendarWidget extends StatelessWidget {
  final bool disablePastDates;
  final String? lawyerUserId;

  const CalendarWidget({
    super.key,
    this.disablePastDates = false,
    this.lawyerUserId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CalendarHeader(),
          CalendarGrid(
            disablePastDates: disablePastDates,
            lawyerUserId: lawyerUserId,
          ),
        ],
      ),
    );
  }
}
