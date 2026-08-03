import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Which slice of the list the notification centre is showing.
enum NotificationFilter { all, unread, people }

/// The segmented control at the top of the notification centre.
///
/// Each tab carries a live count. [peopleLabel] is the only thing that differs
/// between the apps — "Clients" for the lawyer, "Lawyers" for the client — so
/// the control itself is shared.
class NotificationFilterTabs extends StatelessWidget {
  final NotificationFilter selected;
  final ValueChanged<NotificationFilter> onSelected;
  final int allCount;
  final int unreadCount;
  final int peopleCount;
  final String peopleLabel;

  const NotificationFilterTabs({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.allCount,
    required this.unreadCount,
    required this.peopleCount,
    required this.peopleLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Tab(
            label: 'All',
            count: allCount,
            selected: selected == NotificationFilter.all,
            onTap: () => onSelected(NotificationFilter.all),
          ),
          _Tab(
            label: 'Unread',
            count: unreadCount,
            selected: selected == NotificationFilter.unread,
            onTap: () => onSelected(NotificationFilter.unread),
          ),
          _Tab(
            label: peopleLabel,
            count: peopleCount,
            selected: selected == NotificationFilter.people,
            onTap: () => onSelected(NotificationFilter.people),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.onGold : AppColors.secondaryText;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryGold : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: foreground,
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
              child: Text(label),
            ),
            const SizedBox(width: 6),
            Container(
              constraints: const BoxConstraints(minWidth: 20),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.onGold.withValues(alpha: 0.18)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              // Counts change as notifications arrive and are read; the switch
              // keeps that from being a jarring instant swap.
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: Text(
                  '$count',
                  key: ValueKey(count),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
