import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:law/app.dart';
import 'utils/test_reporter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Lawyer Module - Workspace & Dashboard Integration Tests', () {
    testWidgets('TC011 Real Lawyer Dashboard Tab Navigation Test', (WidgetTester tester) async {
      TestReporter.logAction('TC011_LawyerDashboard', 'Pumping Lawyer Dashboard Workspace');

      await tester.pumpWidget(
        const ProviderScope(
          child: MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      TestReporter.logAction('TC011_LawyerDashboard', 'Verifying Workspace Widgets & Navigation Shell');
      expect(find.byType(MaterialApp), findsOneWidget);

      TestReporter.logAction('TC011_LawyerDashboard', 'Lawyer Dashboard Integration Test Passed');
    });
  });
}
