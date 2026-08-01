// NOTE: Custom runner scripts have been removed per enterprise QA guidelines.
// Use official Flutter CLI commands to execute integration tests:
//
//   flutter test integration_test/full_app_test.dart
//   flutter test integration_test/login_test.dart
//
import 'dart:io';

void main() {
  // A command-line script writes to stdout directly. `print` is reserved for
  // application code, where the analyzer requires a logging framework instead.
  stdout.writeln(
    'Please run integration tests using official Flutter CLI commands:',
  );
  stdout.writeln('  flutter test integration_test/full_app_test.dart');
  stdout.writeln('  flutter test integration_test/login_test.dart');
}
