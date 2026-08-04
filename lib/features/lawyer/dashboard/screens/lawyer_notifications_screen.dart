import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../notifications/domain/notification_presentation.dart';
import '../../../notifications/screens/notification_center_screen.dart';
import '../../../../routes/route_names.dart';

/// Tabs of the lawyer dashboard shell, as indexed by its bottom navigation.
class LawyerDashboardTab {
  LawyerDashboardTab._();

  static const int leads = 2;
  static const int clients = 3;
  static const int calendar = 4;
  static const int profile = 5;
}

/// The lawyer's notification centre.
///
/// Rendered inside the dashboard shell rather than pushed as a route, so most
/// destinations are a tab switch handled by the shell through [onOpenTab]
/// rather than a navigation of its own.
class LawyerNotificationsScreen extends ConsumerWidget {
  final VoidCallback onBack;

  /// Switches the dashboard to the given bottom-navigation tab.
  final ValueChanged<int>? onOpenTab;

  const LawyerNotificationsScreen({
    super.key,
    required this.onBack,
    this.onOpenTab,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NotificationCenterScreen(
      peopleLabel: "Clients",
      onBack: onBack,
      onOpenSettings: () => context.push(RouteNames.lawyerSettings),
      onOpen: (notification, target) {
        final referenceId = notification.referenceId ?? '';

        switch (target) {
          case NotificationTarget.chat:
            // The chat route is shared by both apps.
            if (referenceId.isEmpty) return false;
            final name = notification.senderName?.trim();
            context.push(
              '/chat/$referenceId/'
              '${Uri.encodeComponent(name?.isNotEmpty == true ? name! : "Chat")}',
            );
            return true;

          case NotificationTarget.caseDetails:
            return _openTab(LawyerDashboardTab.leads);

          case NotificationTarget.appointments:
            return _openTab(LawyerDashboardTab.calendar);

          case NotificationTarget.documents:
            return _openTab(LawyerDashboardTab.clients);

          case NotificationTarget.reviews:
          case NotificationTarget.profile:
            return _openTab(LawyerDashboardTab.profile);

          case NotificationTarget.payments:
          case NotificationTarget.none:
            return false;
        }
      },
    );
  }

  bool _openTab(int index) {
    final handler = onOpenTab;
    if (handler == null) return false;
    handler(index);
    return true;
  }
}
