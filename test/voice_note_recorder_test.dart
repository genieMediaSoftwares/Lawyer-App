import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

import 'package:law/features/client/ai_smart_case/services/live_transcription_service.dart';
import 'package:law/features/client/ai_smart_case/widgets/voice_note_recorder.dart';

/// End-to-end behaviour of the voice note section, driven from a fake
/// recogniser: what the client sees, and what reaches the case.
void main() {
  late _FakeSpeechPlatform platform;
  late List<String> transcripts;

  setUp(() {
    platform = _FakeSpeechPlatform();
    SpeechToTextPlatform.instance = platform;
    transcripts = [];
  });

  Future<void> pump(WidgetTester tester, {Duration max = const Duration(minutes: 5)}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VoiceNoteRecorder(
              maxDuration: max,
              onTranscriptChanged: transcripts.add,
              onAudioChanged: (_) {},
              // A private recogniser per test; the app-wide singleton would
              // carry one test's initialised state into the next.
              transcriptionServiceFactory: () =>
                  LiveTranscriptionService(speech: SpeechToText.withMethodChannel()),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> startRecording(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Record a voice note'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Taps Stop and lets the post-stop grace period and the plugin's own
  /// final-result timer run out.
  Future<void> stopRecording(WidgetTester tester) async {
    await tester.tap(find.text('Stop'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  testWidgets('words appear while speaking, before Stop is pressed',
      (tester) async {
    await pump(tester);
    await startRecording(tester);

    expect(find.text('Listening…'), findsOneWidget);

    platform.emitResult('my landlord has not returned');
    await tester.pump();
    expect(find.textContaining('my landlord has not returned'), findsOneWidget);

    platform.emitResult('my landlord has not returned the deposit');
    await tester.pump();
    expect(
      find.textContaining('my landlord has not returned the deposit'),
      findsOneWidget,
    );

    // Still recording — nothing has been finalised or handed to the case yet.
    expect(find.text('Stop'), findsOneWidget);
    expect(transcripts.where((t) => t.isNotEmpty), isEmpty);
  });

  testWidgets('Stop hands over an editable transcript straight away',
      (tester) async {
    await pump(tester);
    await startRecording(tester);

    platform.emitResult('the notice was served on 3 March', isFinal: true);
    await tester.pump();

    await tester.tap(find.text('Stop'));
    await tester.pump();

    // Editable immediately, with no intermediate "transcribing" state.
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'the notice was served on 3 March',
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Voice note transcribed'), findsOneWidget);
    expect(transcripts.last, 'the notice was served on 3 March');
  });

  testWidgets('editing the transcript is what reaches the case', (tester) async {
    await pump(tester);
    await startRecording(tester);
    platform.emitResult('teh notice was servd', isFinal: true);
    await tester.pump();
    await stopRecording(tester);

    await tester.enterText(find.byType(TextField), 'the notice was served');
    await tester.pump();

    expect(transcripts.last, 'the notice was served');
  });

  testWidgets('an empty recording says so and hands nothing over',
      (tester) async {
    await pump(tester);
    await startRecording(tester);

    // The client taps Stop without saying anything.
    await stopRecording(tester);

    expect(find.textContaining('did not catch anything'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(transcripts.where((t) => t.isNotEmpty), isEmpty);
  });

  testWidgets('a refused microphone is explained, not crashed on',
      (tester) async {
    platform.initializeResult = false;
    platform.permission = false;

    await pump(tester);
    await startRecording(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('Microphone access'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a silence timeout keeps listening and keeps the words',
      (tester) async {
    await pump(tester);
    await startRecording(tester);

    platform.emitResult('there is a boundary dispute', isFinal: true);
    await tester.pump();

    platform.emitError('error_speech_timeout', permanent: false);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Listening…'), findsOneWidget);
    expect(find.textContaining('there is a boundary dispute'), findsOneWidget);

    await stopRecording(tester);
    expect(transcripts.last, 'there is a boundary dispute');
  });

  testWidgets('losing the network ends the session but keeps the transcript',
      (tester) async {
    await pump(tester);
    await startRecording(tester);

    platform.emitResult('the builder abandoned the site', isFinal: true);
    await tester.pump();

    platform.emitError('error_network', permanent: true);
    await tester.pumpAndSettle();

    expect(find.textContaining('internet connection'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(transcripts.last, 'the builder abandoned the site');
  });

  testWidgets('re-recording replaces the transcript rather than appending',
      (tester) async {
    await pump(tester);
    await startRecording(tester);
    platform.emitResult('first attempt', isFinal: true);
    await tester.pump();
    await stopRecording(tester);

    await tester.tap(find.text('Re-record'));
    await tester.pump();
    expect(transcripts.last, '', reason: 'the old transcript is dropped first');

    platform.emitResult('second attempt', isFinal: true);
    await tester.pump();
    await stopRecording(tester);

    expect(transcripts.last, 'second attempt');
  });

  testWidgets('Add more appends to the existing transcript', (tester) async {
    await pump(tester);
    await startRecording(tester);
    platform.emitResult('the deposit was never returned', isFinal: true);
    await tester.pump();
    await stopRecording(tester);

    await tester.tap(find.text('Add more'));
    await tester.pump();
    platform.emitResult('and the agreement was never signed', isFinal: true);
    await tester.pump();
    await stopRecording(tester);

    expect(
      transcripts.last,
      'the deposit was never returned and the agreement was never signed',
    );
  });

  testWidgets('cancelling an Add more session restores the earlier transcript',
      (tester) async {
    await pump(tester);
    await startRecording(tester);
    platform.emitResult('the original account', isFinal: true);
    await tester.pump();
    await stopRecording(tester);

    await tester.tap(find.text('Add more'));
    await tester.pump();
    platform.emitResult('something said by mistake');
    await tester.pump();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // The screen must not claim there is no voice note while the case still
    // carries one.
    expect(find.byType(TextField), findsOneWidget);
    expect(transcripts.last, 'the original account');
  });

  testWidgets('Delete clears the transcript and the case', (tester) async {
    await pump(tester);
    await startRecording(tester);
    platform.emitResult('something to remove', isFinal: true);
    await tester.pump();
    await stopRecording(tester);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Tap mic and start speaking'), findsOneWidget);
    expect(transcripts.last, '');
  });

  testWidgets('recording auto-stops at the maximum duration', (tester) async {
    await pump(tester, max: const Duration(minutes: 1));
    await startRecording(tester);

    platform.emitResult('a long account', isFinal: true);
    await tester.pump();

    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();

    expect(find.text('Listening…'), findsNothing);
    expect(find.textContaining('1-minute limit'), findsOneWidget);
    expect(transcripts.last, 'a long account');
  });

  testWidgets('backgrounding stops recording and keeps what was said',
      (tester) async {
    await pump(tester);
    await startRecording(tester);

    platform.emitResult('the hearing is on the ninth', isFinal: true);
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Listening…'), findsNothing);
    expect(find.textContaining('went to the background'), findsOneWidget);
    expect(transcripts.last, 'the hearing is on the ninth');

    // The interruption belonged to that session only. A new recording must not
    // inherit it and stop itself the moment it starts.
    // Coming back to the app. Flutter produces no frames while paused, so the
    // screen catches up here — as it does for a real client returning to it.
    // The real return path: paused → hidden → inactive → resumed.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Re-record'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Listening…'), findsOneWidget);
  });

  testWidgets('the microphone is released when the screen goes away',
      (tester) async {
    await pump(tester);
    await startRecording(tester);
    expect(platform.listening, isTrue);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pumpAndSettle();

    expect(platform.listening, isFalse, reason: 'the recogniser was released');
    expect(tester.takeException(), isNull);
  });
}

/// Stands in for the device recogniser.
class _FakeSpeechPlatform extends SpeechToTextPlatform {
  bool initializeResult = true;
  bool permission = true;
  bool listening = false;
  int listenCalls = 0;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<bool> initialize({
    debugLogging = false,
    List<SpeechConfigOption>? options,
  }) async =>
      initializeResult;

  @override
  Future<bool> listen({
    String? localeId,
    partialResults = true,
    onDevice = false,
    int listenMode = 0,
    sampleRate = 0,
    SpeechListenOptions? options,
  }) async {
    listenCalls++;
    listening = true;
    onStatus?.call('listening');
    return true;
  }

  @override
  Future<void> stop() async => listening = false;

  @override
  Future<void> cancel() async => listening = false;

  @override
  Future<List<dynamic>> locales() async => <String>['en_IN:English (India)'];

  void emitResult(String words, {bool isFinal = false}) {
    onTextRecognition?.call(jsonEncode({
      'alternates': [
        {'recognizedWords': words, 'confidence': 0.9},
      ],
      'resultType': isFinal ? 2 : 0,
    }));
  }

  void emitError(String errorMsg, {required bool permanent}) {
    onError?.call(jsonEncode({'errorMsg': errorMsg, 'permanent': permanent}));
  }
}
