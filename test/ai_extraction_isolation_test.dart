import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:law/features/client/ai_smart_case/models/ai_smart_case_models.dart';
import 'package:law/features/client/ai_smart_case/providers/ai_smart_case_provider.dart';
import 'package:law/features/client/ai_smart_case/repositories/ai_smart_case_repository.dart';

/// Every analysis must stand entirely on its own.
///
/// The reported failure was "upload document A, it extracts correctly; upload
/// document B and the old data is still there or the extraction fails". Two
/// client-side defects produced it, and each has a test here:
///
///  * `copyWith` kept `result` on the `x ?? this.x` form, so the `result: null`
///    that was supposed to clear the previous extraction did nothing; and
///  * the stream's `onDone` decided success by reading `state.result`, which
///    was therefore still document A's.
///
/// Together they meant a second analysis that returned nothing opened the form
/// pre-filled from the first document.
void main() {
  group('a new analysis discards the previous one', () {
    test('a failed second run does not surface the first run\'s result', () async {
      final repository = _FakeRepository()
        ..enqueueResult(_result('session-a', title: 'Document A matter'))
        // Second run: the stream closes without ever delivering a result.
        ..enqueueSilence();

      final notifier = AISmartCaseNotifier(repository);
      addTearDown(notifier.dispose);

      notifier.addFiles([_file('a.pdf')]);
      expect(await notifier.startExtraction(), isTrue);
      expect(notifier.state.result?.extracted.title, 'Document A matter');

      // Now the second document.
      notifier.clearForNewIntake();
      notifier.addFiles([_file('b.pdf')]);

      final succeeded = await notifier.startExtraction();

      expect(succeeded, isFalse, reason: 'the second analysis produced nothing');
      expect(
        notifier.state.result,
        isNull,
        reason: "document A's extraction must not survive into document B's run",
      );
      expect(notifier.state.errorMessage, isNotNull);
    });

    test('the previous result is cleared before the upload even starts', () async {
      final repository = _FakeRepository()
        ..enqueueResult(_result('session-a', title: 'Document A matter'))
        ..enqueueSilence();

      final notifier = AISmartCaseNotifier(repository);
      addTearDown(notifier.dispose);

      notifier.addFiles([_file('a.pdf')]);
      await notifier.startExtraction();

      notifier.addFiles([_file('b.pdf')]);
      final pending = notifier.startExtraction();

      // Synchronously after the call, before any network work resolves.
      expect(notifier.state.result, isNull);
      expect(notifier.state.sessionId, isNull);
      expect(notifier.state.progress.stage, 'uploading');

      await pending;
    });

    test('a second run replaces the first result with its own', () async {
      final repository = _FakeRepository()
        ..enqueueResult(_result('session-a', title: 'Document A matter'))
        ..enqueueResult(_result('session-b', title: 'Document B matter'));

      final notifier = AISmartCaseNotifier(repository);
      addTearDown(notifier.dispose);

      notifier.addFiles([_file('a.pdf')]);
      await notifier.startExtraction();

      notifier.clearForNewIntake();
      notifier.addFiles([_file('b.pdf')]);
      expect(await notifier.startExtraction(), isTrue);

      expect(notifier.state.result?.extracted.title, 'Document B matter');
      expect(notifier.state.sessionId, 'session-b');
    });
  });

  group('intake inputs', () {
    test('clearForNewIntake drops the previous document', () async {
      final repository = _FakeRepository()
        ..enqueueResult(_result('session-a', title: 'Document A matter'));

      final notifier = AISmartCaseNotifier(repository);
      addTearDown(notifier.dispose);

      notifier.addFiles([_file('a.pdf')]);
      await notifier.startExtraction();

      notifier.clearForNewIntake();
      notifier.addFiles([_file('b.pdf')]);

      expect(
        notifier.state.selectedFiles.map((f) => f.name),
        ['b.pdf'],
        reason: 'picking a new document must not append to the previous one',
      );
    });

    test('clearForNewIntake leaves progress alone', () async {
      final repository = _FakeRepository()
        ..enqueueResult(_result('session-a', title: 'A'));

      final notifier = AISmartCaseNotifier(repository);
      addTearDown(notifier.dispose);

      notifier.addFiles([_file('a.pdf')]);
      await notifier.startExtraction();
      expect(notifier.state.progress.stage, 'completed');

      // The processing screen is still animating out and reads this; resetting
      // it would snap its timeline back to the first stage on the way off.
      notifier.clearForNewIntake();
      expect(notifier.state.progress.stage, 'completed');
    });

    test('only the newest document is uploaded on the second run', () async {
      final repository = _FakeRepository()
        ..enqueueResult(_result('session-a', title: 'A'))
        ..enqueueResult(_result('session-b', title: 'B'));

      final notifier = AISmartCaseNotifier(repository);
      addTearDown(notifier.dispose);

      notifier.addFiles([_file('a.pdf')]);
      await notifier.startExtraction();

      notifier.clearForNewIntake();
      notifier.addFiles([_file('b.pdf')]);
      await notifier.startExtraction();

      expect(repository.uploadsPerRun, [
        ['a.pdf'],
        ['b.pdf'],
      ]);
    });
  });

  group('duplicate requests', () {
    test('a second start while one is in flight is refused', () async {
      final repository = _FakeRepository()..enqueueResult(_result('session-a'));

      final notifier = AISmartCaseNotifier(repository);
      addTearDown(notifier.dispose);

      notifier.addFiles([_file('a.pdf')]);

      final first = notifier.startExtraction();
      final second = await notifier.startExtraction();

      expect(second, isFalse);
      await first;
      expect(
        repository.startCalls,
        1,
        reason: 'the documents must not be uploaded twice',
      );
    });

    test('starting with no document reports it and uploads nothing', () async {
      final repository = _FakeRepository();
      final notifier = AISmartCaseNotifier(repository);
      addTearDown(notifier.dispose);

      expect(await notifier.startExtraction(), isFalse);
      expect(notifier.state.errorMessage, isNotNull);
      expect(repository.startCalls, 0);
    });
  });

  group('AISmartCaseState.copyWith', () {
    test('clearResult removes the result; omitting it keeps the result', () {
      final state = AISmartCaseState(result: _result('s'));

      expect(state.copyWith(clearResult: true).result, isNull);
      expect(state.copyWith(isExtracting: true).result, isNotNull);
    });

    test('clearSessionId removes the session id', () {
      const state = AISmartCaseState(sessionId: 's');

      expect(state.copyWith(clearSessionId: true).sessionId, isNull);
      expect(state.copyWith(isExtracting: true).sessionId, 's');
    });
  });
}

ExtractionResult _result(String sessionId, {String title = ''}) {
  return ExtractionResult(
    sessionId: sessionId,
    extracted: ExtractedCaseData(title: title),
  );
}

PlatformFile _file(String name) =>
    PlatformFile(name: name, size: 10, bytes: null);

/// Serves a scripted stream per run, and records what each run uploaded.
class _FakeRepository implements AISmartCaseRepository {
  final List<ExtractionResult?> _scripted = [];
  final List<List<String>> uploadsPerRun = [];
  int startCalls = 0;

  /// The next run completes with [result].
  void enqueueResult(ExtractionResult result) => _scripted.add(result);

  /// The next run's stream closes without delivering anything.
  void enqueueSilence() => _scripted.add(null);

  @override
  Future<String> startAnalysis({
    required List<PlatformFile> files,
    File? voiceFile,
    String? issueDescription,
  }) async {
    uploadsPerRun.add(files.map((f) => f.name).toList());
    final index = startCalls;
    startCalls++;
    final scripted = index < _scripted.length ? _scripted[index] : null;
    return scripted?.sessionId ?? 'session-$startCalls';
  }

  @override
  Stream<AnalysisEvent> watch(String sessionId) {
    final scripted = _scripted.firstWhere(
      (r) => r?.sessionId == sessionId,
      orElse: () => null,
    );

    return Stream<AnalysisEvent>.fromIterable([
      if (scripted != null) AnalysisEvent.complete(scripted),
    ]);
  }

  @override
  Future<void> linkSessionToCase({
    required String sessionId,
    required String caseId,
  }) async {}
}
