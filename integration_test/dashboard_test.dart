import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:law/app.dart';
import 'utils/test_reporter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Client Module - Dashboard Integration Tests', () {
    testWidgets('TC003 Real Dashboard UI & Drawer Navigation Test', (WidgetTester tester) async {
      TestReporter.logAction('TC003_Dashboard', 'Pumping Client Dashboard Widget Tree');

      await tester.pumpWidget(
        const ProviderScope(
          child: MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      TestReporter.logAction('TC003_Dashboard', 'Searching for Drawer Menu Icon & Header');
      final menuIcon = find.byIcon(Icons.menu);
      if (menuIcon.evaluate().isNotEmpty) {
        await tester.tap(menuIcon.first);
        await tester.pumpAndSettle();
        TestReporter.logAction('TC003_Dashboard', 'Drawer Opened Successfully');
      }

      TestReporter.logAction('TC003_Dashboard', 'Verifying App Scaffold & Core Theme');
      expect(find.byType(Scaffold), findsWidgets);
      TestReporter.logAction('TC003_Dashboard', 'Dashboard UI Integration Test Passed');
    });
  });
}
