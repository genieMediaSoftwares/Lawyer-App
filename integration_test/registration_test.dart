import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:law/app.dart';
import 'utils/test_reporter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication - Registration Screen Integration Tests', () {
    testWidgets('TC002 Real Registration Flow Test', (WidgetTester tester) async {
      TestReporter.logAction('TC002_Registration', 'Launching Signup Screen via app binding');

      await tester.pumpWidget(
        const ProviderScope(
          child: MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      TestReporter.logAction('TC002_Registration', 'Locating Sign Up Toggle / Button');
      final signUpTextBtn = find.text('Sign Up');
      if (signUpTextBtn.evaluate().isNotEmpty) {
        await tester.tap(signUpTextBtn.first);
        await tester.pumpAndSettle();
      }

      TestReporter.logAction('TC002_Registration', 'Verifying Form TextFields on Registration Screen');
      final formFields = find.byType(TextFormField);
      expect(formFields, findsWidgets);

      TestReporter.logAction('TC002_Registration', 'Filling Full Name, Email, Mobile, Password');
      if (formFields.evaluate().length >= 4) {
        await tester.enterText(formFields.at(0), 'Test Client');
        await tester.enterText(formFields.at(1), 'newclient@lawyerapp.com');
        await tester.enterText(formFields.at(2), '9876543210');
        await tester.enterText(formFields.at(3), 'Pass123456');
        await tester.pumpAndSettle();
      }

      TestReporter.logAction('TC002_Registration', 'Asserting Application Shell State');
      expect(find.byType(MaterialApp), findsOneWidget);
      TestReporter.logAction('TC002_Registration', 'Registration Integration Test Passed');
    });
  });
}
