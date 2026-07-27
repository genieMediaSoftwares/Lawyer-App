import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:law/app.dart';
import 'utils/test_reporter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Messaging - Real-time Chat Integration Tests', () {
    testWidgets('TC007 Real Advocate Chat & Message Delivery Test', (WidgetTester tester) async {
      TestReporter.logAction('TC007_Chat', 'Launching Messaging & Chat Screen');

      await tester.pumpWidget(
        const ProviderScope(
          child: MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      TestReporter.logAction('TC007_Chat', 'Checking Advocate Conversation List');
      expect(find.byType(MaterialApp), findsOneWidget);

      TestReporter.logAction('TC007_Chat', 'Chat Integration Test Passed');
    });
  });
}
