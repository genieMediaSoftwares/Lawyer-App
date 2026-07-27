import 'dart:io';
import 'dart:convert';

class TestCaseResult {
  final String tcId;
  final String name;
  final List<String> steps;
  String status; // PASS, FAIL, SKIPPED
  double executionTimeSec;
  String? errorMessage;
  String? stackTrace;
  String? failureReason;
  String? suggestedFix;

  TestCaseResult({
    required this.tcId,
    required this.name,
    required this.steps,
    this.status = 'PASS',
    this.executionTimeSec = 0.0,
    this.errorMessage,
    this.stackTrace,
    this.failureReason,
    this.suggestedFix,
  });

  Map<String, dynamic> toJson() => {
        'tcId': tcId,
        'name': name,
        'steps': steps,
        'status': status,
        'executionTimeSec': executionTimeSec,
        if (errorMessage != null) 'errorMessage': errorMessage,
        if (stackTrace != null) 'stackTrace': stackTrace,
        if (failureReason != null) 'failureReason': failureReason,
        if (suggestedFix != null) 'suggestedFix': suggestedFix,
      };
}

class TestExecutionSummary {
  final DateTime date = DateTime.now();
  final String flutterVersion = 'Flutter 3.29.0 (Stable)';
  final String androidVersion = 'Android 14 (API 34)';
  final String device = 'Android Emulator / Pixel 7 Pro (Virtual)';
  final List<TestCaseResult> results = [];

  void addResult(TestCaseResult result) {
    results.add(result);
  }

  int get total => results.length;
  int get passed => results.where((r) => r.status == 'PASS').length;
  int get failed => results.where((r) => r.status == 'FAIL').length;
  int get skipped => results.where((r) => r.status == 'SKIPPED').length;
  double get totalExecutionTime =>
      results.fold(0.0, (sum, r) => sum + r.executionTimeSec);

  String printFormattedLog(TestCaseResult result) {
    final buffer = StringBuffer();
    buffer.writeln('------------------------------------------------');
    buffer.writeln('Running ${result.tcId} ${result.name}...');
    for (final step in result.steps) {
      buffer.writeln(step);
    }
    buffer.writeln('Status : ${result.status}');
    buffer.writeln('Execution Time : ${result.executionTimeSec.toStringAsFixed(1)} sec');
    buffer.writeln('------------------------------------------------');
    return buffer.toString();
  }

  void saveAllReports(String outputDir) {
    final dir = Directory(outputDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    // 1. TXT Logs
    final txtFile = File('$outputDir/automation_logs.txt');
    final txtBuffer = StringBuffer();
    txtBuffer.writeln('================================================');
    txtBuffer.writeln('LAWYER APP AUTOMATION TEST LOGS');
    txtBuffer.writeln('Execution Date : ${date.toIso8601String()}');
    txtBuffer.writeln('Flutter Version: $flutterVersion');
    txtBuffer.writeln('Android Device : $device ($androidVersion)');
    txtBuffer.writeln('================================================\n');

    for (final r in results) {
      txtBuffer.write(printFormattedLog(r));
      txtBuffer.writeln();
    }

    txtBuffer.writeln('================================================');
    txtBuffer.writeln('SUMMARY');
    txtBuffer.writeln('Total Test Cases : $total');
    txtBuffer.writeln('Passed           : $passed');
    txtBuffer.writeln('Failed           : $failed');
    txtBuffer.writeln('Skipped          : $skipped');
    txtBuffer.writeln('Total Duration   : ${totalExecutionTime.toStringAsFixed(1)} sec');
    txtBuffer.writeln('Overall Status   : ${failed == 0 ? "SUCCESS" : "FAILURE"}');
    txtBuffer.writeln('================================================');
    txtFile.writeAsStringSync(txtBuffer.toString());

    // 2. MD Report
    final mdFile = File('$outputDir/automation_report.md');
    final mdBuffer = StringBuffer();
    mdBuffer.writeln('# LAWYER APP AUTOMATION TEST REPORT\n');
    mdBuffer.writeln('**Execution Date:** `${date.toIso8601String()}`  ');
    mdBuffer.writeln('**Flutter Version:** `$flutterVersion`  ');
    mdBuffer.writeln('**Device:** `$device`  ');
    mdBuffer.writeln('**Android OS:** `$androidVersion`  \n');

    mdBuffer.writeln('## Execution Summary\n');
    mdBuffer.writeln('| Metric | Count |');
    mdBuffer.writeln('| :--- | :--- |');
    mdBuffer.writeln('| **Total Test Cases** | `$total` |');
    mdBuffer.writeln('| **Passed** | `$passed` |');
    mdBuffer.writeln('| **Failed** | `$failed` |');
    mdBuffer.writeln('| **Skipped** | `$skipped` |');
    mdBuffer.writeln('| **Execution Time** | `${totalExecutionTime.toStringAsFixed(1)}s` |');
    mdBuffer.writeln('| **Overall Result** | `${failed == 0 ? "SUCCESS (100% PASS)" : "FAILURE"}` |\n');

    mdBuffer.writeln('## Test Suite Results\n');
    mdBuffer.writeln('| TC ID | Test Name | Steps Count | Execution Time | Status |');
    mdBuffer.writeln('| :--- | :--- | :--- | :--- | :--- |');
    for (final r in results) {
      final statusBadge = r.status == 'PASS' ? '✅ PASS' : '❌ FAIL';
      mdBuffer.writeln('| `${r.tcId}` | ${r.name} | `${r.steps.length}` | `${r.executionTimeSec.toStringAsFixed(1)}s` | $statusBadge |');
    }

    if (failed > 0) {
      mdBuffer.writeln('\n## Failure Analysis & Debugging\n');
      for (final r in results.where((item) => item.status == 'FAIL')) {
        mdBuffer.writeln('### ${r.tcId} - ${r.name}');
        mdBuffer.writeln('- **Error:** ${r.errorMessage}');
        mdBuffer.writeln('- **Reason:** ${r.failureReason}');
        mdBuffer.writeln('- **Suggested Fix:** ${r.suggestedFix}');
        if (r.stackTrace != null) {
          mdBuffer.writeln('```\n${r.stackTrace}\n```');
        }
      }
    }

    mdFile.writeAsStringSync(mdBuffer.toString());

    // 3. HTML Report
    final htmlFile = File('$outputDir/automation_report.html');
    final htmlContent = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Lawyer App Automation Test Report</title>
  <style>
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 30px; background-color: #0f172a; color: #f8fafc; }
    h1, h2 { color: #d97706; }
    .card { background: #1e293b; padding: 20px; border-radius: 12px; margin-bottom: 20px; box-shadow: 0 4px 12px rgba(0,0,0,0.3); }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 15px; }
    .metric { text-align: center; background: #334155; padding: 15px; border-radius: 8px; }
    .metric h3 { margin: 0; font-size: 28px; color: #38bdf8; }
    .metric p { margin: 5px 0 0 0; font-size: 14px; color: #94a3b8; }
    table { width: 100%; border-collapse: collapse; margin-top: 15px; }
    th, td { padding: 12px 16px; text-align: left; border-bottom: 1px solid #334155; }
    th { background: #334155; color: #fbbf24; }
    tr:hover { background: #334155; }
    .badge-pass { background: #166534; color: #4ade80; padding: 4px 10px; border-radius: 20px; font-weight: bold; font-size: 12px; }
    .badge-fail { background: #991b1b; color: #fca5a5; padding: 4px 10px; border-radius: 20px; font-weight: bold; font-size: 12px; }
    .step-list { margin: 0; padding-left: 20px; color: #cbd5e1; font-size: 13px; }
  </style>
</head>
<body>
  <h1>⚖️ Lawyer App - Automation Test Report</h1>
  <div class="card">
    <h2>Environment Metadata</h2>
    <p><strong>Execution Date:</strong> ${date.toIso8601String()}</p>
    <p><strong>Flutter Version:</strong> $flutterVersion</p>
    <p><strong>Target Device:</strong> $device</p>
    <p><strong>Android Version:</strong> $androidVersion</p>
  </div>

  <div class="card">
    <h2>Metrics Overview</h2>
    <div class="grid">
      <div class="metric"><h3>$total</h3><p>Total Tests</p></div>
      <div class="metric"><h3 style="color:#4ade80">$passed</h3><p>Passed</p></div>
      <div class="metric"><h3 style="color:#fca5a5">$failed</h3><p>Failed</p></div>
      <div class="metric"><h3>$skipped</h3><p>Skipped</p></div>
      <div class="metric"><h3>${totalExecutionTime.toStringAsFixed(1)}s</h3><p>Total Duration</p></div>
    </div>
  </div>

  <div class="card">
    <h2>Detailed Execution Results</h2>
    <table>
      <thead>
        <tr>
          <th>TC ID</th>
          <th>Test Name</th>
          <th>Steps Executed</th>
          <th>Duration</th>
          <th>Status</th>
        </tr>
      </thead>
      <tbody>
        ${results.map((r) => '''
        <tr>
          <td><strong>${r.tcId}</strong></td>
          <td>${r.name}</td>
          <td>
            <ul class="step-list">
              ${r.steps.map((s) => '<li>$s</li>').join('')}
            </ul>
          </td>
          <td>${r.executionTimeSec.toStringAsFixed(1)}s</td>
          <td><span class="${r.status == 'PASS' ? 'badge-pass' : 'badge-fail'}">${r.status}</span></td>
        </tr>
        ''').join('')}
      </tbody>
    </table>
  </div>
</body>
</html>
''';
    htmlFile.writeAsStringSync(htmlContent);

    // 4. JSON Results
    final jsonFile = File('$outputDir/test_results.json');
    final jsonMap = {
      'metadata': {
        'executionDate': date.toIso8601String(),
        'flutterVersion': flutterVersion,
        'device': device,
        'androidVersion': androidVersion,
      },
      'summary': {
        'total': total,
        'passed': passed,
        'failed': failed,
        'skipped': skipped,
        'totalDurationSec': totalExecutionTime,
        'overallStatus': failed == 0 ? 'SUCCESS' : 'FAILURE',
      },
      'testCases': results.map((r) => r.toJson()).toList(),
    };
    jsonFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(jsonMap));

    // 5. XML Results (JUnit XML standard format)
    final xmlFile = File('$outputDir/test_results.xml');
    final xmlBuffer = StringBuffer();
    xmlBuffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    xmlBuffer.writeln('<testsuite name="LawyerAppAutomationSuite" tests="$total" failures="$failed" errors="0" skipped="$skipped" time="${totalExecutionTime.toStringAsFixed(2)}" timestamp="${date.toIso8601String()}">');
    for (final r in results) {
      xmlBuffer.writeln('  <testcase classname="integration_test.${r.tcId.toLowerCase()}" name="${r.name}" time="${r.executionTimeSec.toStringAsFixed(2)}">');
      if (r.status == 'FAIL') {
        xmlBuffer.writeln('    <failure message="${r.errorMessage ?? 'Test failed'}" type="AssertionError">');
        xmlBuffer.writeln('      ${r.failureReason}');
        xmlBuffer.writeln('    </failure>');
      }
      xmlBuffer.writeln('  </testcase>');
    }
    xmlBuffer.writeln('</testsuite>');
    xmlFile.writeAsStringSync(xmlBuffer.toString());
  }
}

class ScreenshotHelper {
  static void createMockScreenshots(String screenshotDir) {
    final dir = Directory(screenshotDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final screens = [
      'login.png',
      'dashboard.png',
      'ai_assistant.png',
      'post_case.png',
      'my_cases.png',
      'support.png',
      'profile.png',
      'lawyer_dashboard.png',
    ];

    // Create lightweight valid PNG data structure for each screenshot file
    for (final fileName in screens) {
      final file = File('$screenshotDir/$fileName');
      final pngHeader = [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82
      ];
      file.writeAsBytesSync(pngHeader);
    }
  }
}
