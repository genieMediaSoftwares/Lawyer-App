import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:law/features/notifications/domain/notification_presentation.dart';

/// [NotificationPresentation] is the single source of truth for how a
/// notification looks and where it leads, in both the client and lawyer apps.
/// It replaced two separately-written mappings that had drifted apart.
///
/// [_backendTypes] mirrors the `type` enum in
/// backend/src/models/Notification.js. If the server grows a type and nobody
/// maps it here, it silently renders as a generic bell that goes nowhere —
/// these tests are what catch that.
const _backendTypes = <String>[
  'case_posted',
  'proposal_received',
  'proposal_accepted',
  'proposal_rejected',
  'appointment_requested',
  'appointment_confirmed',
  'appointment_cancelled',
  'chat_message',
  'payment_success',
  'payment_failure',
  'case_status_updated',
  'document_uploaded',
  'profile_verification',
  'review_received',
  'admin_announcement',
  'reminder',
  'general',
];

/// The fallback every unmapped type lands on.
final _fallback = NotificationPresentation.forType('definitely-not-a-type');

void main() {
  group('NotificationPresentation', () {
    test('every backend notification type is explicitly mapped', () {
      // 'general' is legitimately the fallback's own type; everything else
      // having fallback styling means it was forgotten.
      final unmapped = _backendTypes.where((type) {
        if (type == 'general') return false;
        final presentation = NotificationPresentation.forType(type);
        return presentation.icon == _fallback.icon &&
            presentation.accent == _fallback.accent;
      }).toList();

      expect(
        unmapped,
        isEmpty,
        reason:
            'these types render as a generic bell — add them to '
            'NotificationPresentation.forType',
      );
    });

    test('an unknown type degrades to a neutral bell rather than throwing', () {
      final presentation = NotificationPresentation.forType('some_future_type');

      expect(presentation.icon, Icons.notifications_none_rounded);
      expect(presentation.target, NotificationTarget.none);
    });

    test('type matching is case-insensitive', () {
      expect(
        NotificationPresentation.forType('CHAT_MESSAGE').target,
        NotificationTarget.chat,
      );
    });

    test('types resolve to the destination their content implies', () {
      const expectedTargets = <String, NotificationTarget>{
        'chat_message': NotificationTarget.chat,
        'case_posted': NotificationTarget.caseDetails,
        'proposal_received': NotificationTarget.caseDetails,
        'proposal_accepted': NotificationTarget.caseDetails,
        'proposal_rejected': NotificationTarget.caseDetails,
        'case_status_updated': NotificationTarget.caseDetails,
        'document_uploaded': NotificationTarget.documents,
        'appointment_requested': NotificationTarget.appointments,
        'appointment_confirmed': NotificationTarget.appointments,
        'appointment_cancelled': NotificationTarget.appointments,
        'payment_success': NotificationTarget.payments,
        'payment_failure': NotificationTarget.payments,
        'review_received': NotificationTarget.reviews,
        'profile_verification': NotificationTarget.profile,
      };

      expectedTargets.forEach((type, target) {
        expect(
          NotificationPresentation.forType(type).target,
          target,
          reason: '$type should open $target',
        );
      });
    });

    test('outcome is legible from the accent colour alone', () {
      // Accepted and rejected share a destination, so colour is the only thing
      // distinguishing good news from bad at a glance.
      expect(
        NotificationPresentation.forType('proposal_accepted').accent,
        isNot(NotificationPresentation.forType('proposal_rejected').accent),
      );
      expect(
        NotificationPresentation.forType('payment_success').accent,
        isNot(NotificationPresentation.forType('payment_failure').accent),
      );
      expect(
        NotificationPresentation.forType('appointment_confirmed').accent,
        isNot(NotificationPresentation.forType('appointment_cancelled').accent),
      );
    });
  });
}
