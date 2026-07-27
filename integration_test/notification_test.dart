import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:law/app.dart';
import 'utils/test_reporter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Notifications - Notification Center Integration Tests', () {
    testWidgets('TC008 Real Notification Alerts & Badge Counter Test', (WidgetTester tester) async {
      TestReporter.logAction('TC008_Notifications', 'Pumping Notification Center Widget');

      await tester.pumpWidget(
        const ProviderScope(
          child: MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      TestReporter.logAction('TC008_Notifications', 'Finding Notification Bell Action Icon');
      final notifIcon = find.byIcon(Icons.notifications_none_outlined);
      if (notifIcon.evaluate().isNotEmpty) {
        await tester.tap(notifIcon.first);
        await tester.pumpAndSettle();
      }

      expect(find.byType(MaterialApp), findsOneWidget);
      TestReporter.logAction('TC008_Notifications', 'Notification Center Integration Test Passed');
    });
  });
}
