import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes/route_names.dart';
import '../../../notifications/domain/notification_presentation.dart';
import '../../../notifications/screens/notification_center_screen.dart';

/// The client's notification centre.
///
/// The screen itself is shared with the lawyer app; this only supplies the
/// client's vocabulary and its navigation, which goes through named routes.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NotificationCenterScreen(
      peopleLabel: "Lawyers",
      onBack: () => context.pop(),
      onOpenSettings: () => context.push(RouteNames.settings),
      onOpen: (notification, target) {
        final referenceId = notification.referenceId ?? '';

        switch (target) {
          case NotificationTarget.chat:
            if (referenceId.isEmpty) return false;
            final name = notification.senderName?.trim();
            context.push(
              '/chat/$referenceId/'
              '${Uri.encodeComponent(name?.isNotEmpty == true ? name! : "Chat")}',
            );
            return true;

          case NotificationTarget.caseDetails:
            if (referenceId.isEmpty) return false;
            context.push('/case-progress/$referenceId');
            return true;

          case NotificationTarget.appointments:
            context.push(RouteNames.consult);
            return true;

          case NotificationTarget.documents:
            context.push(RouteNames.myDocuments);
            return true;

          case NotificationTarget.profile:
            context.push(RouteNames.profile);
            return true;

          // No client-facing screen for these yet. The card still marks
          // itself read; it just has nowhere to go.
          case NotificationTarget.payments:
          case NotificationTarget.reviews:
          case NotificationTarget.none:
            return false;
        }
      },
    );
  }
}
