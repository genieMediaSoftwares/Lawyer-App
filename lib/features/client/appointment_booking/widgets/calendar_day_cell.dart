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

  static const _navy = Color(0xFF0B1F4D);
  static const _gold = Color(0xFFD4A537);

  @override
  Widget build(BuildContext context) {
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
                color: isSelected ? _navy : Colors.transparent,
                border: isSelected
                    ? Border.all(color: _gold, width: 2.5)
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected
                      ? Colors.white
                      : isDisabled
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF0F172A),
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
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _gold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
