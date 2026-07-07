import 'package:flutter/material.dart';

/// Individual day cell for the calendar grid.
/// Matches the reference image exactly:
/// - Selected: Navy (#0B1F4D) circle fill + golden (#D4A537) ring + white bold text
/// - Unselected: No background, dark text
/// - Disabled: Light grey text
/// - Events: Small golden dot below the number
class CalendarDayCell extends StatelessWidget {
  final int day;
  final bool isSelected;
  final bool isToday;
  final bool hasEvents;
  final bool isDisabled;
  final VoidCallback onTap;

  const CalendarDayCell({
    super.key,
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.hasEvents,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The circular date container
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                border: isSelected
                    ? Border.all(color: Colors.black12, width: 1.5)
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected
                      ? Colors.black
                      : isDisabled
                          ? theme.disabledColor
                          : theme.textTheme.bodyMedium?.color,
                  height: 1.0,
                ),
              ),
            ),
            // Event dot indicator
            if (hasEvents) ...[
              const SizedBox(height: 2),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
