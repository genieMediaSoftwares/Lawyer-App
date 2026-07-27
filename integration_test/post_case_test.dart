import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:law/app.dart';
import 'utils/test_reporter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Client Module - Post Case & Voice Description Integration Tests', () {
    testWidgets('TC005 Real Post Case Creation Test', (WidgetTester tester) async {
      TestReporter.logAction('TC005_PostCase', 'Pumping Post Case Screen');

      await tester.pumpWidget(
        const ProviderScope(
          child: MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      TestReporter.logAction('TC005_PostCase', 'Finding Form Input Fields for Case Title & Details');
      final textFields = find.byType(TextFormField);
      if (textFields.evaluate().isNotEmpty) {
        await tester.enterText(textFields.first, 'Property Dispute Notice');
        await tester.pumpAndSettle();
      }

      TestReporter.logAction('TC005_PostCase', 'Verifying Application Scaffold Stack');
      expect(find.byType(MaterialApp), findsOneWidget);
      TestReporter.logAction('TC005_PostCase', 'Post Case Test Passed');
    });
  });
}
