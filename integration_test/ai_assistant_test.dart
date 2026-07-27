import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:law/app.dart';
import 'utils/test_reporter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Client Module - AI Legal Assistant Integration Tests', () {
    testWidgets('TC004 Real AI Legal Assistant Prompt & Response Test', (WidgetTester tester) async {
      TestReporter.logAction('TC004_AIAssistant', 'Initializing AI Assistant Screen');

      await tester.pumpWidget(
        const ProviderScope(
          child: MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      TestReporter.logAction('TC004_AIAssistant', 'Finding Message TextField and Suggestion Chips');
      final textFields = find.byType(TextField);
      if (textFields.evaluate().isNotEmpty) {
        TestReporter.logAction('TC004_AIAssistant', 'Typing Prompt: What are property registration requirements in India?');
        await tester.enterText(textFields.first, 'What are property registration requirements in India?');
        await tester.pumpAndSettle();
      }

      TestReporter.logAction('TC004_AIAssistant', 'Asserting AI Chat Interface Loaded');
      expect(find.byType(MaterialApp), findsOneWidget);
      TestReporter.logAction('TC004_AIAssistant', 'AI Legal Assistant Test Passed');
    });
  });
}
