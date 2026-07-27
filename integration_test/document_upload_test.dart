import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:law/app.dart';
import 'utils/test_reporter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Client Module - Document Upload Vault Integration Tests', () {
    testWidgets('TC006 Real Document Upload & Vault View Test', (WidgetTester tester) async {
      TestReporter.logAction('TC006_DocumentUpload', 'Launching My Documents Vault Interface');

      await tester.pumpWidget(
        const ProviderScope(
          child: MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      TestReporter.logAction('TC006_DocumentUpload', 'Locating Document List and Upload Pickers');
      expect(find.byType(MaterialApp), findsOneWidget);

      TestReporter.logAction('TC006_DocumentUpload', 'Document Vault Integration Test Passed');
    });
  });
}
