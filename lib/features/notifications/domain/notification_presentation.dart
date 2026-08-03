import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Where tapping a notification should take the user.
///
/// A target rather than a route on purpose: the two apps reach the same
/// destination by different means — the client pushes a named route, the
/// lawyer switches a dashboard tab — so each shell resolves these its own way
/// and neither has to know about the other's navigation.
enum NotificationTarget {
  chat,
  caseDetails,
  appointments,
  documents,
  payments,
  reviews,
  profile,

  /// Nothing useful to open. The card still marks itself read on tap.
  none,
}

/// How one notification type is drawn and where it leads.
///
/// The single source of truth for this mapping. It previously lived twice —
/// once in each notification screen — with different icons, different colours
/// and different type coverage, so the same event looked like two unrelated
/// things depending on which app you were in.
@immutable
class NotificationPresentation {
  final IconData icon;
  final Color accent;
  final NotificationTarget target;

  const NotificationPresentation({
    required this.icon,
    required this.accent,
    required this.target,
  });

  /// Resolves the presentation for a backend notification `type`.
  ///
  /// Unknown types fall back to a neutral bell rather than being dropped:
  /// the server's enum can grow ahead of the app, and a notification with no
  /// styling is still worth showing.
  factory NotificationPresentation.forType(String type) {
    switch (type.toLowerCase()) {
      // ── Cases ──────────────────────────────────────────────────────────
      case 'case_posted':
      case 'proposal_received':
        return const NotificationPresentation(
          icon: Icons.gavel_rounded,
          accent: AppColors.primaryGold,
          target: NotificationTarget.caseDetails,
        );
      case 'proposal_accepted':
        return const NotificationPresentation(
          icon: Icons.check_circle_outline_rounded,
          accent: AppColors.success,
          target: NotificationTarget.caseDetails,
        );
      case 'proposal_rejected':
        return const NotificationPresentation(
          icon: Icons.cancel_outlined,
          accent: AppColors.error,
          target: NotificationTarget.caseDetails,
        );
      case 'case_status_updated':
        return const NotificationPresentation(
          icon: Icons.description_outlined,
          accent: AppColors.success,
          target: NotificationTarget.caseDetails,
        );

      // ── Messaging ──────────────────────────────────────────────────────
      case 'chat_message':
        return const NotificationPresentation(
          icon: Icons.chat_bubble_outline_rounded,
          accent: AppColors.info,
          target: NotificationTarget.chat,
        );

      // ── Documents ──────────────────────────────────────────────────────
      case 'document_uploaded':
        return const NotificationPresentation(
          icon: Icons.attach_file_rounded,
          accent: AppColors.statPurple,
          target: NotificationTarget.documents,
        );

      // ── Appointments ───────────────────────────────────────────────────
      case 'appointment_requested':
        return const NotificationPresentation(
          icon: Icons.event_available_outlined,
          accent: AppColors.primaryGold,
          target: NotificationTarget.appointments,
        );
      case 'appointment_confirmed':
        return const NotificationPresentation(
          icon: Icons.event_available_outlined,
          accent: AppColors.success,
          target: NotificationTarget.appointments,
        );
      case 'appointment_cancelled':
        return const NotificationPresentation(
          icon: Icons.event_busy_outlined,
          accent: AppColors.error,
          target: NotificationTarget.appointments,
        );

      // ── Money ──────────────────────────────────────────────────────────
      case 'payment_success':
        return const NotificationPresentation(
          icon: Icons.payments_outlined,
          accent: AppColors.success,
          target: NotificationTarget.payments,
        );
      case 'payment_failure':
        return const NotificationPresentation(
          icon: Icons.payments_outlined,
          accent: AppColors.error,
          target: NotificationTarget.payments,
        );

      // ── Reputation & account ───────────────────────────────────────────
      case 'review_received':
        return const NotificationPresentation(
          icon: Icons.star_outline_rounded,
          accent: AppColors.primaryGold,
          target: NotificationTarget.reviews,
        );
      case 'profile_verification':
        return const NotificationPresentation(
          icon: Icons.verified_user_outlined,
          accent: AppColors.info,
          target: NotificationTarget.profile,
        );

      // ── System ─────────────────────────────────────────────────────────
      case 'admin_announcement':
        return const NotificationPresentation(
          icon: Icons.campaign_outlined,
          accent: AppColors.warning,
          target: NotificationTarget.none,
        );
      case 'reminder':
        return const NotificationPresentation(
          icon: Icons.alarm_rounded,
          accent: AppColors.warning,
          target: NotificationTarget.none,
        );
      default:
        return const NotificationPresentation(
          icon: Icons.notifications_none_rounded,
          accent: AppColors.info,
          target: NotificationTarget.none,
        );
    }
  }
}
