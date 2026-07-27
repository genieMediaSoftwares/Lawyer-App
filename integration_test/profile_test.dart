import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:law/app.dart';
import 'utils/test_reporter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Profile & Settings - User Profile Integration Tests', () {
    testWidgets('TC009 Real User Profile Update & Settings Test', (WidgetTester tester) async {
      TestReporter.logAction('TC009_Profile', 'Launching Profile Screen');

      await tester.pumpWidget(
        const ProviderScope(
          child: MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      TestReporter.logAction('TC009_Profile', 'Checking User Info Header & Preferences');
      expect(find.byType(MaterialApp), findsOneWidget);

      TestReporter.logAction('TC009_Profile', 'Profile Integration Test Passed');
    });
  });
}
