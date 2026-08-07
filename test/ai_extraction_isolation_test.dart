import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
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

  group('voice note', () {
    test('the live transcript is uploaded with the documents', () async {
      final repository = _FakeRepository()..enqueueResult(_result('session-a'));

      final notifier = AISmartCaseNotifier(repository);
      addTearDown(notifier.dispose);

      notifier.addFiles([_file('a.pdf')]);
      notifier.setVoiceTranscript('the landlord changed the locks on 3 March');
      notifier.setWrittenNotes('rent receipts are in the second PDF');

      await notifier.startExtraction();

      // Both reach the pipeline in the one request, as distinct inputs. The
      // transcript used to be produced server-side from the audio *after* this
      // upload, which is the wait this replaced.
      expect(
        repository.transcriptsPerRun,
        ['the landlord changed the locks on 3 March'],
      );
      expect(repository.notesPerRun, ['rent receipts are in the second PDF']);
    });

    test('the transcript and the typed notes do not overwrite each other', () {
      final notifier = AISmartCaseNotifier(_FakeRepository());
      addTearDown(notifier.dispose);

      notifier.setVoiceTranscript('spoken account');
      notifier.setWrittenNotes('typed account');

      expect(notifier.state.voiceTranscript, 'spoken account');
      expect(notifier.state.writtenNotes, 'typed account');
    });

    test('clearForNewIntake drops the previous transcript and notes', () async {
      final repository = _FakeRepository()
        ..enqueueResult(_result('session-a'))
        ..enqueueResult(_result('session-b'));

      final notifier = AISmartCaseNotifier(repository);
      addTearDown(notifier.dispose);

      notifier.addFiles([_file('a.pdf')]);
      notifier.setVoiceTranscript('first matter');
      notifier.setWrittenNotes('first notes');
      await notifier.startExtraction();

      notifier.clearForNewIntake();
      notifier.addFiles([_file('b.pdf')]);
      await notifier.startExtraction();

      expect(repository.transcriptsPerRun, ['first matter', '']);
      expect(repository.notesPerRun, ['first notes', '']);
    });
  });

  group('duplicate requests', () {
    test('a second start while one is in flight joins it rather than duplicating',
        () async {
      final repository = _FakeRepository()..enqueueResult(_result('session-a'));

      final notifier = AISmartCaseNotifier(repository);
      addTearDown(notifier.dispose);

      notifier.addFiles([_file('a.pdf')]);

      final first = notifier.startExtraction();
      final second = notifier.startExtraction();

      // Both callers see the same outcome. Returning false to the second caller
      // — as this used to — left the processing screen believing the analysis
      // had failed while it was in fact still running, so it sat on a spinner
      // that nothing would ever resolve.
      expect(await first, isTrue);
      expect(await second, isTrue);

      expect(
        repository.startCalls,
        1,
        reason: 'the documents must not be uploaded twice',
      );
    });

    test('a start after a finished run reuses the result without re-uploading',
        () async {
      final repository = _FakeRepository()..enqueueResult(_result('session-a'));

      final notifier = AISmartCaseNotifier(repository);
      addTearDown(notifier.dispose);

      notifier.addFiles([_file('a.pdf')]);
      expect(await notifier.startExtraction(), isTrue);

      // The processing screen rebuilding must not re-analyse documents we
      // already have an answer for.
      expect(await notifier.startExtraction(), isTrue);
      expect(repository.startCalls, 1);
    });

    test('each intake carries its own idempotency key', () async {
      final repository = _FakeRepository()
        ..enqueueResult(_result('session-a'))
        ..enqueueResult(_result('session-b'));

      final notifier = AISmartCaseNotifier(repository);
      addTearDown(notifier.dispose);

      notifier.addFiles([_file('a.pdf')]);
      await notifier.startExtraction();

      notifier.clearForNewIntake();
      notifier.addFiles([_file('b.pdf')]);
      await notifier.startExtraction();

      expect(repository.requestIds, hasLength(2));
      expect(
        repository.requestIds.first,
        isNot(repository.requestIds.last),
        reason: 'a shared key would make the second intake replay the first',
      );
      expect(repository.requestIds.every((id) => id.isNotEmpty), isTrue);
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

  group('failure handling and recovery', () {
    test('a stream error settles the run instead of leaving it extracting',
        () async {
      final repository = _FakeRepository()..enqueueStreamError('the socket died');

      final notifier = AISmartCaseNotifier(repository);
      addTearDown(notifier.dispose);

      notifier.addFiles([_file('a.pdf')]);

      expect(await notifier.startExtraction(), isFalse);
      expect(notifier.state.isExtracting, isFalse);
      expect(notifier.state.errorMessage, contains('the socket died'));
    });

    test('a progress event after a failure does not clear the error', () async {
      final repository = _FakeRepository()..enqueueFailureThenProgress();

      final notifier = AISmartCaseNotifier(repository);
      addTearDown(notifier.dispose);

      notifier.addFiles([_file('a.pdf')]);
      await notifier.startExtraction();

      // A packet already in flight when the run failed used to wipe the banner
      // through copyWith's unconditional `errorMessage` assignment, so the
      // screen went back to looking as though the analysis were still running.
      expect(notifier.state.errorMessage, isNotNull);
      expect(notifier.state.isExtracting, isFalse);
    });

    test('a retry after a failure starts a genuinely new run', () async {
      final repository = _FakeRepository()
        ..enqueueStreamError('transient')
        ..enqueueResult(_result('session-b', title: 'Recovered'));

      final notifier = AISmartCaseNotifier(repository);
      addTearDown(notifier.dispose);

      notifier.addFiles([_file('a.pdf')]);
      expect(await notifier.startExtraction(), isFalse);

      expect(await notifier.startExtraction(), isTrue);
      expect(notifier.state.result?.extracted.title, 'Recovered');
      expect(notifier.state.errorMessage, isNull);
      expect(repository.startCalls, 2);
    });

    test('cancelRun stops the run and releases the subscription', () async {
      final repository = _FakeRepository()..enqueueNeverEnding();

      final notifier = AISmartCaseNotifier(repository);
      addTearDown(notifier.dispose);

      notifier.addFiles([_file('a.pdf')]);
      final pending = notifier.startExtraction();

      // Let the upload resolve and the subscription attach.
      await Future<void>.delayed(Duration.zero);
      notifier.cancelRun();

      expect(await pending, isFalse);
      expect(notifier.state.isExtracting, isFalse);
      expect(repository.openWatches, 0, reason: 'the watch must be cancelled');
      // The client's documents survive, so they can retry without re-picking.
      expect(notifier.state.selectedFiles, hasLength(1));
    });
  });

  group('upload progress', () {
    test('the uploading stage reports real bytes and stops short of the '
        'analysis', () async {
      final repository = _FakeRepository()..enqueueNeverEnding();

      final notifier = AISmartCaseNotifier(repository);
      addTearDown(notifier.dispose);

      final seen = <AnalysisProgress>[];
      notifier.addListener((s) => seen.add(s.progress));

      notifier.addFiles([_file('a.pdf')]);
      unawaited(notifier.startExtraction());
      await Future<void>.delayed(Duration.zero);

      final uploading = seen.where((p) => p.stage == 'uploading').toList();
      expect(uploading, isNotEmpty);
      // The bar must never reach 100% merely because the bytes were sent — the
      // analysis has not started at that point.
      expect(uploading.every((p) => p.percent <= 15), isTrue);

      notifier.cancelRun();
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

/// One scripted outcome for a run.
class _Script {
  final ExtractionResult? result;
  final String? streamError;
  final bool failureThenProgress;
  final bool neverEnds;

  const _Script({
    this.result,
    this.streamError,
    this.failureThenProgress = false,
    this.neverEnds = false,
  });
}

/// Serves a scripted stream per run, and records what each run uploaded.
class _FakeRepository implements AISmartCaseRepository {
  final List<_Script> _scripted = [];
  final List<List<String>> uploadsPerRun = [];

  /// The voice transcript each run uploaded, so a test can assert the live
  /// transcript travels with the documents rather than after them.
  final List<String> transcriptsPerRun = [];

  /// The typed notes each run uploaded.
  final List<String> notesPerRun = [];

  int startCalls = 0;

  /// Watches handed out and not yet cancelled or closed. A run that leaks its
  /// subscription shows up here as a non-zero count.
  int openWatches = 0;

  /// The next run completes with [result].
  void enqueueResult(ExtractionResult result) =>
      _scripted.add(_Script(result: result));

  /// The next run's stream closes without delivering anything.
  void enqueueSilence() => _scripted.add(const _Script());

  /// The next run's stream errors, as a dropped socket or a failed poll does.
  void enqueueStreamError(String message) =>
      _scripted.add(_Script(streamError: message));

  /// The next run fails and *then* a stale progress packet lands.
  void enqueueFailureThenProgress() =>
      _scripted.add(const _Script(failureThenProgress: true));

  /// The next run's stream never produces anything and never closes.
  void enqueueNeverEnding() => _scripted.add(const _Script(neverEnds: true));

  /// Every idempotency key the notifier has presented, in order. Repeats across
  /// retries of one intake are the point of the key; repeats across separate
  /// intakes would defeat it.
  final List<String> requestIds = [];

  @override
  Future<String> startAnalysis({
    required List<PlatformFile> files,
    File? voiceFile,
    String? voiceTranscript,
    String? issueDescription,
    required String requestId,
    CancelToken? cancelToken,
    void Function(int sent, int total)? onProgress,
  }) async {
    uploadsPerRun.add(files.map((f) => f.name).toList());
    transcriptsPerRun.add(voiceTranscript ?? '');
    notesPerRun.add(issueDescription ?? '');
    requestIds.add(requestId);

    // Exercises the caller's upload-progress handling without a network.
    onProgress?.call(512, 1024);
    onProgress?.call(1024, 1024);
    final index = startCalls;
    startCalls++;
    final scripted = index < _scripted.length ? _scripted[index] : null;
    return scripted?.result?.sessionId ?? 'session-$startCalls';
  }

  @override
  Stream<AnalysisEvent> watch(String sessionId) {
    // Runs are consumed in order, so the script for this watch is the one whose
    // upload has just happened.
    final script =
        startCalls - 1 < _scripted.length && startCalls > 0 ? _scripted[startCalls - 1] : null;

    late StreamController<AnalysisEvent> controller;
    controller = StreamController<AnalysisEvent>(
      onListen: () {
        openWatches++;

        if (script == null || script.neverEnds) return;

        scheduleMicrotask(() {
          if (controller.isClosed) return;

          if (script.streamError != null) {
            controller.addError(Exception(script.streamError));
            controller.close();
            openWatches--;
            return;
          }

          if (script.failureThenProgress) {
            controller.add(const AnalysisEvent.failed('The analysis failed.'));
            // A packet that was already on the wire when the run failed.
            controller.add(
              const AnalysisEvent.progress(
                AnalysisProgress(stage: 'ocr', message: 'Reading…', percent: 40),
              ),
            );
            controller.close();
            openWatches--;
            return;
          }

          if (script.result != null) {
            controller.add(AnalysisEvent.complete(script.result!));
          }
          controller.close();
          openWatches--;
        });
      },
      onCancel: () {
        if (!controller.isClosed) openWatches--;
      },
    );

    return controller.stream;
  }

  @override
  Future<void> linkSessionToCase({
    required String sessionId,
    required String caseId,
  }) async {}
}
