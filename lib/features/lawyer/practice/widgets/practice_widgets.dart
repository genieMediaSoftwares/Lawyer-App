import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

/// Shared building blocks for the six practice-management screens.
///
/// They exist so Cases, Documents, Research, Clients, Hearings and Notes read
/// as one section rather than six screens that happen to sit next to each
/// other — the same empty state, the same search field, the same status pill.
/// Every colour comes from [AppColors] or the active [ThemeData]; none is
/// written inline.

/// The widest a practice screen's content is allowed to grow.
///
/// On a phone this changes nothing. On web and tablet it stops a list of cases
/// from stretching to a 1600px line length, which is unreadable and looks
/// broken next to the rest of the app.
const double kPracticeMaxContentWidth = 840;

/// Centres and caps [child] at [kPracticeMaxContentWidth].
class PracticeContentWidth extends StatelessWidget {
  const PracticeContentWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kPracticeMaxContentWidth),
        child: child,
      ),
    );
  }
}

/// The empty state used by every practice screen.
///
/// Takes a title and a line of guidance rather than just a title: "No cases
/// yet" alone leaves an advocate wondering whether something is broken, where
/// "accept a request from My Leads" tells them what to do next.
class PracticeEmptyState extends StatelessWidget {
  const PracticeEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedText,
                  height: 1.5,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// The error state used by every practice screen.
///
/// Always offers a retry: these screens all read from providers that can be
/// invalidated, and a dead end with no way back is the worst of the three
/// states to land in.
class PracticeErrorState extends StatelessWidget {
  const PracticeErrorState({super.key, this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return PracticeEmptyState(
      icon: Icons.error_outline,
      title: loc.something_went_wrong,
      message: message,
      action: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh, size: 18),
        label: Text(loc.retry),
      ),
    );
  }
}

/// The search field used by Cases, Documents, Clients and Notes.
class PracticeSearchField extends StatelessWidget {
  const PracticeSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: hintText,
        isDense: true,
        prefixIcon: const Icon(Icons.search, size: 20),
        // Rebuilt from the controller so the clear button appears as soon as
        // there is something to clear, without the parent having to rebuild.
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, child) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: loc.clear_search,
              onPressed: () {
                controller.clear();
                onChanged('');
              },
            );
          },
        ),
      ),
    );
  }
}

/// A small filled pill for a case or hearing status.
class PracticeStatusPill extends StatelessWidget {
  const PracticeStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled block with a trailing action, used to separate the sections of the
/// case and client detail screens.
class PracticeSectionHeader extends StatelessWidget {
  const PracticeSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// A bordered card matching the one the lawyer dashboard already uses.
class PracticeCard extends StatelessWidget {
  const PracticeCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Maps a Case.status onto a colour from the palette.
///
/// The status strings are the server's own enum values and are matched
/// case-insensitively, because different endpoints have historically returned
/// "Closed" and "closed" for the same state. An unrecognised status falls
/// through to a neutral colour rather than throwing.
Color practiceCaseStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'in progress':
      return AppColors.info;
    case 'accepted':
    case 'interested':
      return AppColors.primaryGold;
    case 'closed':
    case 'completed':
    case 'resolved':
      return AppColors.success;
    case 'rejected':
      return AppColors.error;
    case 'submitted':
    case 'pending lawyer response':
    case 'awaiting lawyer acceptance':
      return AppColors.warning;
    default:
      return AppColors.mutedText;
  }
}

/// Maps a hearing status onto a colour.
Color practiceHearingStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'completed':
      return AppColors.success;
    case 'adjourned':
      return AppColors.warning;
    case 'cancelled':
      return AppColors.error;
    case 'scheduled':
    default:
      return AppColors.info;
  }
}

/// The localized label for a hearing status.
String practiceHearingStatusLabel(AppLocalizations loc, String status) {
  switch (status.toLowerCase()) {
    case 'completed':
      return loc.hearing_status_completed;
    case 'adjourned':
      return loc.hearing_status_adjourned;
    case 'cancelled':
      return loc.hearing_status_cancelled;
    case 'scheduled':
    default:
      return loc.hearing_status_scheduled;
  }
}
