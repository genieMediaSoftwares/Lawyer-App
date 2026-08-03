import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:law/features/notifications/screens/notification_center_screen.dart';
import 'package:law/models/notification_model.dart';
import 'package:law/providers/notification_provider.dart';

/// Renders the notification centre at every screen size the app supports, and
/// at the text scales an accessibility setting can impose, asserting nothing
/// overflows.
///
/// A RenderFlex overflow is reported through FlutterError, which the test
/// binding surfaces via `tester.takeException()` — so "no yellow-and-black
/// stripes on a small phone" is a thing that can actually be asserted rather
/// than eyeballed on one device.
void main() {
  // Logical sizes, smallest realistic phone upward.
  const sizes = <String, Size>{
    'small phone (320x640)': Size(320, 640),
    'compact phone (360x740)': Size(360, 740),
    'standard phone (411x890)': Size(411, 890),
    'large phone (480x1000)': Size(480, 1000),
    'tablet (768x1024)': Size(768, 1024),
  };

  // 1.0 is the default; 1.3 is a common accessibility bump, and the case that
  // breaks layouts built around fixed-width text.
  const textScales = <double>[1.0, 1.3];

  group('NotificationCenterScreen layout', () {
    for (final entry in sizes.entries) {
      for (final scale in textScales) {
        testWidgets('${entry.key} @ ${scale}x text does not overflow', (
          tester,
        ) async {
          await _pumpCentre(
            tester,
            size: entry.value,
            textScale: scale,
            notifications: _sampleNotifications(),
          );

          expect(
            tester.takeException(),
            isNull,
            reason: 'layout overflowed at ${entry.key} with ${scale}x text',
          );
        });
      }
    }

    testWidgets('long titles and messages wrap rather than overflow', (
      tester,
    ) async {
      await _pumpCentre(
        tester,
        size: const Size(320, 640),
        textScale: 1.3,
        notifications: [
          _notification(
            id: 'long',
            type: 'case_posted',
            title:
                'An extremely long notification title that no small screen '
                'could ever hope to fit on a single line',
            message:
                'A correspondingly long body describing a direct case request '
                '"Ajay Kumar vs. Ravi Kumar and several other named parties" '
                'that continues well past the width of the card.',
          ),
        ],
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('empty and error states fit on the smallest screen', (
      tester,
    ) async {
      await _pumpCentre(
        tester,
        size: const Size(320, 640),
        textScale: 1.3,
        notifications: const [],
      );
      expect(tester.takeException(), isNull);
      expect(find.text('No Notifications Yet'), findsOneWidget);
    });

    testWidgets('the settings action is optional and leaves the header balanced', (
      tester,
    ) async {
      await _pumpCentre(
        tester,
        size: const Size(320, 640),
        textScale: 1.3,
        notifications: _sampleNotifications(),
        withSettings: false,
      );

      expect(tester.takeException(), isNull);
    });

    // Both apps render this same screen; only the third tab's label differs.
    for (final label in const ['Clients', 'Lawyers']) {
      testWidgets('the "$label" tab fits on the smallest screen', (
        tester,
      ) async {
        await _pumpCentre(
          tester,
          size: const Size(320, 640),
          textScale: 1.3,
          notifications: _sampleNotifications(),
          peopleLabel: label,
        );

        expect(tester.takeException(), isNull);
        expect(find.text(label), findsOneWidget);
      });
    }

    testWidgets('date groups are built from timestamps', (tester) async {
      await _pumpCentre(
        tester,
        size: const Size(411, 890),
        textScale: 1.0,
        notifications: _sampleNotifications(),
      );

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Earlier'), findsOneWidget);
    });
  });
}

Future<void> _pumpCentre(
  WidgetTester tester, {
  required Size size,
  required double textScale,
  required List<NotificationModel> notifications,
  bool withSettings = true,
  String peopleLabel = 'Clients',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationsProvider.overrideWith(
          (ref) => _StubNotificationNotifier(notifications),
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          home: NotificationCenterScreen(
            peopleLabel: peopleLabel,
            onBack: () {},
            onOpenSettings: withSettings ? () {} : null,
            onOpen: (_, _) => false,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Serves a fixed list without touching the network or a socket.
///
/// `NotificationNotifier(null)` deliberately skips both: its constructor only
/// initialises when it has a user id.
class _StubNotificationNotifier extends NotificationNotifier {
  _StubNotificationNotifier(List<NotificationModel> items) : super(null) {
    state = NotificationState(
      notifications: items,
      isLoading: false,
      isLoadMore: false,
      unreadCount: items.where((n) => !n.isRead).length,
      isOffline: false,
      page: 1,
      hasMore: false,
    );
  }
}

List<NotificationModel> _sampleNotifications() {
  final now = DateTime.now();
  return [
    _notification(
      id: '1',
      type: 'case_posted',
      title: 'New Case Request',
      message: 'You received a direct case request "Ajay Kumar vs. Ravi Kumar".',
      createdAt: now.subtract(const Duration(hours: 1)),
    ),
    _notification(
      id: '2',
      type: 'case_status_updated',
      title: 'Case Started',
      message:
          'You have started working on case "Ajay Kumar vs. Ravi Kumar - '
          'Property Dispute".',
      createdAt: now.subtract(const Duration(hours: 3)),
    ),
    _notification(
      id: '3',
      type: 'proposal_accepted',
      title: 'Case Request Accepted',
      message: 'You have accepted a new case request.',
      createdAt: now.subtract(const Duration(days: 1)),
      isRead: true,
    ),
    _notification(
      id: '4',
      type: 'document_uploaded',
      title: 'New Document Uploaded',
      message:
          'A new document has been uploaded in "Ajay Kumar vs. Ravi Kumar".',
      createdAt: now.subtract(const Duration(days: 1, hours: 2)),
    ),
    _notification(
      id: '5',
      type: 'chat_message',
      title: 'New Message',
      message: 'You have a new message from Ajay Kumar.',
      createdAt: now.subtract(const Duration(days: 4)),
      isRead: true,
    ),
  ];
}

NotificationModel _notification({
  required String id,
  required String type,
  required String title,
  required String message,
  DateTime? createdAt,
  bool isRead = false,
}) {
  final when = createdAt ?? DateTime.now();
  return NotificationModel(
    id: id,
    notificationId: id,
    senderId: 'sender-$id',
    senderName: 'Ajay Kumar',
    receiverId: 'me',
    title: title,
    message: message,
    type: type,
    priority: 'low',
    metadata: const {},
    referenceId: 'ref-$id',
    isRead: isRead,
    softDelete: false,
    createdAt: when,
    updatedAt: when,
  );
}
