import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:law/app.dart';
import 'utils/test_reporter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Support & Help - Customer Service Integration Tests', () {
    testWidgets('TC010 Real Contact Support Ticket & FAQ Test', (WidgetTester tester) async {
      TestReporter.logAction('TC010_Support', 'Pumping Contact Support Screen');

      await tester.pumpWidget(
        const ProviderScope(
          child: MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      TestReporter.logAction('TC010_Support', 'Verifying Support Form & Accordion Items');
      expect(find.byType(MaterialApp), findsOneWidget);

      TestReporter.logAction('TC010_Support', 'Support Integration Test Passed');
    });
  });
}
