import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart' show Amplitude;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

import 'package:law/features/client/ai_smart_case/services/live_transcription_service.dart';
import 'package:law/features/client/ai_smart_case/services/microphone_permission.dart';
import 'package:law/features/client/ai_smart_case/services/voice_audio_capture.dart';
import 'package:law/features/client/ai_smart_case/services/voice_language.dart';
import 'package:law/features/client/ai_smart_case/widgets/voice_note_recorder.dart';

/// End-to-end behaviour of the voice note section, driven from a fake
/// recogniser: what the client sees, and what reaches the case.
void main() {
  late _FakeSpeechPlatform platform;
  late List<String> transcripts;
  late List<String> languages;
  late _FakePermission permission;
  late _FakeAudioCapture capture;

  setUp(() {
    platform = _FakeSpeechPlatform();
    SpeechToTextPlatform.instance = platform;
    transcripts = [];
    languages = [];
    permission = _FakePermission();
    capture = _FakeAudioCapture();
  });

  Future<void> pump(
    WidgetTester tester, {
    Duration max = const Duration(minutes: 5),
    List<String>? locales,
    VoiceLanguageChoice? language,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VoiceNoteRecorder(
              maxDuration: max,
              preferredLocales: locales,
              // Mirrors the widget's own default: the first preferred locale's
              // language, and English when nothing was asked for.
              initialLanguage: language ??
                  VoiceLanguageChoice.of(
                    VoiceLanguage.forCode(locales?.first) ??
                        VoiceLanguage.english,
                  ),
              permission: permission.build(),
              audioCaptureFactory: () => capture,
              onTranscriptChanged: transcripts.add,
              onLanguageChanged: languages.add,
              onAudioChanged: (_) {},
              // A private recogniser per test; the app-wide singleton would
              // carry one test's initialised state into the next.
              transcriptionServiceFactory: () => LiveTranscriptionService(
                speech: SpeechToText.withMethodChannel(),
                permission: permission.build(),
              ),
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
    permission.status = PermissionStatus.denied;

    await pump(tester);
    await startRecording(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('Microphone access'), findsOneWidget);
    // Retryable, so no Settings detour is pushed at the client.
    expect(find.text('Open Settings'), findsNothing);
    expect(find.byTooltip('Record a voice note'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a granted microphone records, with no permission notice',
      (tester) async {
    permission.status = PermissionStatus.granted;

    await pump(tester);
    await startRecording(tester);

    expect(find.text('Listening…'), findsOneWidget);
    expect(find.textContaining('Microphone access'), findsNothing);
    expect(find.textContaining('not available'), findsNothing);
  });

  testWidgets('a permanently denied microphone offers Open Settings',
      (tester) async {
    permission.status = PermissionStatus.permanentlyDenied;

    await pump(tester);
    await startRecording(tester);
    await tester.pumpAndSettle();

    // The message names the cause and the remedy - not "the microphone is not
    // available", which was neither.
    expect(find.textContaining('turned off for this app'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);

    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
    expect(permission.settingsOpened, 1);
  });

  testWidgets('a restricted microphone is explained without a dead-end button',
      (tester) async {
    permission.status = PermissionStatus.restricted;

    await pump(tester);
    await startRecording(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('blocked on this device'), findsOneWidget);
    expect(find.text('Open Settings'), findsNothing);
  });

  testWidgets('a recogniser that will not start records for the backend '
      'instead of blaming the microphone', (tester) async {
    platform.initializeThrows = true;

    await pump(tester);
    await startRecording(tester);
    await tester.pumpAndSettle();

    // Permission is granted, so the client is never told the microphone is
    // unavailable; the note is recorded and transcribed after upload.
    expect(find.textContaining('microphone is not available'), findsNothing);
    expect(find.textContaining('transcribe it after upload'), findsOneWidget);
  });

  testWidgets('the language selector offers all four options and switches',
      (tester) async {
    await pump(tester);

    expect(find.text('Auto'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('తెలుగు'), findsOneWidget);
    expect(find.text('हिन्दी'), findsOneWidget);

    await tester.tap(find.text('తెలుగు'));
    await tester.pump();

    platform.supportedLocales = const ['te_IN:Telugu (India)'];
    await startRecording(tester);

    // The recogniser was asked for Telugu because the chip was tapped, with no
    // change to the app's own language.
    expect(platform.lastLocaleId, 'te_IN');
  });

  testWidgets('Auto records for backend detection rather than guessing a '
      'language', (tester) async {
    await pump(tester, language: VoiceLanguageChoice.auto);
    await startRecording(tester);
    // Explicit pumps rather than pumpAndSettle: the recording indicator
    // animates for as long as the recorder is up, which never settles.
    await tester.pump(const Duration(milliseconds: 200));

    // No recogniser can detect a language, so none is started in one.
    expect(platform.listenCalls, 0);
    expect(find.textContaining('detected from this recording'), findsOneWidget);
    // Nothing is claimed about the language until the backend has read it.
    expect(languages.where((l) => l.isNotEmpty), isEmpty);
  });

  testWidgets('an explicit Telugu choice never silently becomes English',
      (tester) async {
    // A device with English installed and no Telugu - the configuration that
    // used to hand a Telugu speaker the English recogniser.
    platform.supportedLocales = const ['en_IN:English (India)'];

    await pump(tester, language: VoiceLanguageChoice.telugu);
    await startRecording(tester);
    await tester.pumpAndSettle();

    expect(platform.listenCalls, 0);
    expect(platform.lastLocaleId, isNull);
    expect(transcripts.where((t) => t.isNotEmpty), isEmpty);
    // Routed to the recording fallback, which transcribes in Telugu, rather
    // than to an English recogniser.
    expect(find.textContaining('transcribe it in Telugu after upload'),
        findsOneWidget);
    expect(languages.last, 'te');
  });

  testWidgets('mixed Telugu and English speech keeps both, in both scripts',
      (tester) async {
    platform.supportedLocales = const ['te_IN:Telugu (India)'];
    await pump(tester, language: VoiceLanguageChoice.telugu);
    await startRecording(tester);

    // How a client actually dictates: Telugu sentence, English legal terms.
    const spoken = 'నా FIR లో Section 138 '
        'గురించి '
        'సహాయం కావాలి';
    platform.emitResult(spoken, isFinal: true);
    await tester.pump();
    await stopRecording(tester);

    expect(transcripts.last, spoken);
    expect(transcripts.last, contains('FIR'));
    expect(transcripts.last, contains('Section 138'));
    expect(languages.last, 'te');
    // The English terms do not make it an English transcript, and no warning
    // is raised about them.
    expect(find.textContaining('rather than Telugu'), findsNothing);
  });

  testWidgets('mixed Hindi and English speech keeps both, in both scripts',
      (tester) async {
    platform.supportedLocales = const ['hi_IN:Hindi (India)'];
    await pump(tester, language: VoiceLanguageChoice.hindi);
    await startRecording(tester);

    const spoken = 'मेरी FIR में IPC '
        'Section 420 का मामला '
        'है';
    platform.emitResult(spoken, isFinal: true);
    await tester.pump();
    await stopRecording(tester);

    expect(transcripts.last, spoken);
    expect(transcripts.last, contains('IPC'));
    expect(languages.last, 'hi');
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

  testWidgets('a Telugu voice note reaches the case in Telugu script',
      (tester) async {
    platform.supportedLocales = const ['te_IN:Telugu (India)'];
    await pump(tester, locales: VoiceLanguage.telugu.localeCandidates);
    await startRecording(tester);

    const spoken = 'నాకు నా ఆస్తి కేసు గురించి సహాయం కావాలి';
    platform.emitResult(spoken, isFinal: true);
    await tester.pump();

    // What the client watches appear is already their own language.
    expect(find.textContaining(spoken), findsOneWidget);

    await stopRecording(tester);

    expect(platform.lastLocaleId, 'te_IN');
    expect(transcripts.last, spoken, reason: 'handed over verbatim');
    expect(languages.last, 'te');
    // Not translated, and not spelled out in English letters either.
    expect(RegExp(r'[A-Za-z]').hasMatch(transcripts.last), isFalse);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      spoken,
    );
  });

  testWidgets('a Hindi voice note reaches the case in Devanagari',
      (tester) async {
    platform.supportedLocales = const ['hi_IN:Hindi (India)'];
    await pump(tester, locales: VoiceLanguage.hindi.localeCandidates);
    await startRecording(tester);

    const spoken = 'मुझे अपने संपत्ति मामले के बारे में मदद चाहिए';
    platform.emitResult(spoken, isFinal: true);
    await tester.pump();
    await stopRecording(tester);

    expect(platform.lastLocaleId, 'hi_IN');
    expect(transcripts.last, spoken);
    expect(languages.last, 'hi');
    expect(RegExp(r'[A-Za-z]').hasMatch(transcripts.last), isFalse);
  });

  testWidgets('an English voice note behaves exactly as it did', (tester) async {
    await pump(tester, locales: VoiceLanguage.english.localeCandidates);
    await startRecording(tester);

    platform.emitResult('I need help with my property case', isFinal: true);
    await tester.pump();
    await stopRecording(tester);

    expect(platform.lastLocaleId, 'en_IN');
    expect(transcripts.last, 'I need help with my property case');
    expect(languages.last, 'en');
    expect(find.text('Voice note transcribed'), findsOneWidget);
  });

  testWidgets('a language the device lacks never becomes an English transcript',
      (tester) async {
    // English only — no Telugu pack, the common case on an Indian handset.
    platform.supportedLocales = const ['en_IN:English (India)'];

    await pump(tester, locales: VoiceLanguage.telugu.localeCandidates);
    await startRecording(tester);
    await tester.pumpAndSettle();

    // The recogniser was never started in a language the client did not
    // choose, so there is no English text to insert in place of their Telugu.
    expect(platform.listenCalls, 0);
    expect(platform.lastLocaleId, isNull);
    expect(transcripts.where((t) => t.isNotEmpty), isEmpty);
    // The recording carries Telugu to the backend, which transcribes in it.
    // The one answer that would be wrong here is 'en'.
    expect(languages, isNot(contains('en')));

    // The client is told, and their note is being recorded for the backend to
    // transcribe rather than dropped back to an idle mic button.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Recording…'), findsOneWidget);
    expect(find.textContaining('transcribe it in Telugu after upload'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a recogniser answering in the wrong script warns without '
      'replacing the words', (tester) async {
    platform.supportedLocales = const ['te_IN:Telugu (India)'];
    await pump(tester, locales: VoiceLanguage.telugu.localeCandidates);
    await startRecording(tester);

    // A romanised answer: Telugu words, English letters. Historically this
    // passed for a successful transcription.
    const romanised = 'naaku naa aasthi case gurinchi sahayam kavali';
    platform.emitResult(romanised, isFinal: true);
    await tester.pump();
    await stopRecording(tester);

    expect(find.textContaining('rather than Telugu'), findsOneWidget);
    // Warned, never rewritten or thrown away — the client decides.
    expect(transcripts.last, romanised);
    expect(find.text('Re-record'), findsOneWidget);
  });

  testWidgets('deleting a Telugu note clears its language too', (tester) async {
    platform.supportedLocales = const ['te_IN:Telugu (India)'];
    await pump(tester, locales: VoiceLanguage.telugu.localeCandidates);
    await startRecording(tester);

    platform.emitResult('నా ఆస్తి కేసు', isFinal: true);
    await tester.pump();
    await stopRecording(tester);
    expect(languages.last, 'te');

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(transcripts.last, '');
    expect(languages.last, '');
  });

  testWidgets('a microphone the recorder cannot open says so, and says what to '
      'do about it', (tester) async {
    capture.results = const [
      VoiceCaptureResult.failed(VoiceCaptureFault.recorderFailed, 'busy'),
    ];

    await pump(tester, language: VoiceLanguageChoice.auto);
    await startRecording(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('Close anything else using the microphone'),
        findsOneWidget);
    // Retryable from the mic button; nothing here needs the Settings app.
    expect(find.text('Open Settings'), findsNothing);
    expect(find.byTooltip('Record a voice note'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a recorder that refuses on permission is not blamed on another '
      'app', (tester) async {
    // The failure this widget used to report as "close anything else using the
    // microphone", which is neither the cause nor the remedy.
    capture.results = const [
      VoiceCaptureResult.failed(VoiceCaptureFault.permissionDenied),
    ];

    await pump(tester, language: VoiceLanguageChoice.auto);
    await startRecording(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('Microphone access is needed'), findsOneWidget);
    expect(find.textContaining('Close anything else'), findsNothing);
  });

  testWidgets('a microphone still being handed over is retried, not reported '
      'as an error', (tester) async {
    // What a real device does between releasing the recogniser and opening the
    // recorder: the first attempt lands before the platform has let go.
    capture.results = const [
      VoiceCaptureResult.failed(VoiceCaptureFault.recorderFailed, 'busy'),
      VoiceCaptureResult.ok(),
    ];

    await pump(tester, language: VoiceLanguageChoice.auto);
    await startRecording(tester);
    await tester.pump(const Duration(milliseconds: 600));

    expect(capture.starts, 2);
    expect(find.text('Recording…'), findsOneWidget);
    expect(find.textContaining('Close anything else'), findsNothing);
  });

  testWidgets('a microphone lost mid-recording ends the session instead of '
      'producing an empty file', (tester) async {
    await pump(tester, language: VoiceLanguageChoice.auto);
    await startRecording(tester);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Recording…'), findsOneWidget);

    // Android reports this asynchronously, long after start() succeeded.
    capture.fail('PCM reader failed to initialize.');
    await tester.pumpAndSettle();

    expect(find.text('Recording…'), findsNothing);
    expect(find.textContaining('microphone became unavailable'), findsOneWidget);
    expect(find.byTooltip('Record a voice note'), findsOneWidget);
  });

  testWidgets('the recogniser is released before the recorder asks for the '
      'microphone', (tester) async {
    // A device with no Telugu pack: the recogniser fails and the note falls
    // back to record-and-transcribe-server-side.
    platform.supportedLocales = const ['en_IN:English (India)'];
    capture.micHeldBy = () => platform.listening;

    await pump(tester, language: VoiceLanguageChoice.telugu);
    await startRecording(tester);
    await tester.pumpAndSettle();

    expect(capture.starts, 1);
    expect(capture.recogniserHeldMic, isFalse,
        reason: 'the recogniser must have let the microphone go first');
    expect(find.text('Recording…'), findsOneWidget);
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
  bool initializeThrows = false;
  bool listening = false;
  int listenCalls = 0;
  String? lastLocaleId;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<bool> initialize({
    debugLogging = false,
    List<SpeechConfigOption>? options,
  }) async {
    if (initializeThrows) throw Exception('recogniser failed to start');
    return initializeResult;
  }

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
    lastLocaleId = localeId;
    listening = true;
    onStatus?.call('listening');
    return true;
  }

  @override
  Future<void> stop() async => listening = false;

  @override
  Future<void> cancel() async => listening = false;

  /// The recognition packs this device has. Mutable so a test can take one
  /// away: a handset without a Telugu pack is the norm, not the exception.
  List<String> supportedLocales = const ['en_IN:English (India)'];

  @override
  Future<List<dynamic>> locales() async => supportedLocales;

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

/// Stands in for the device recorder, so a microphone that will not open can be
/// tested without one to take away.
///
/// Extends the real capture rather than reimplementing it, so the widget is
/// driven through exactly the API it uses in production.
class _FakeAudioCapture extends VoiceAudioCapture {
  _FakeAudioCapture() : super(filePrefix: 'test');

  /// Handed back by successive [start] calls; the last entry repeats.
  List<VoiceCaptureResult> results = const [VoiceCaptureResult.ok()];

  int starts = 0;
  bool _recording = false;

  /// Whether the recogniser still had the microphone when the recorder asked
  /// for it — the condition that produced "recording could not be started" on
  /// devices where nothing else was using it.
  bool recogniserHeldMic = false;

  /// Reads the recogniser's state at the moment [start] is called.
  bool Function()? micHeldBy;

  @override
  bool get isActive => _recording;

  @override
  Future<VoiceCaptureResult> start({bool permissionAlreadyGranted = false}) async {
    if (micHeldBy?.call() ?? false) recogniserHeldMic = true;

    final result = results[starts.clamp(0, results.length - 1)];
    starts++;
    if (result.started) _recording = true;
    return result;
  }

  @override
  Stream<Amplitude> amplitudes({
    Duration interval = const Duration(milliseconds: 100),
  }) =>
      const Stream<Amplitude>.empty();

  /// Drives the asynchronous failure Android reports once capture is under way.
  void fail(String detail) {
    _recording = false;
    onFailure?.call(detail);
  }

  @override
  Future<File?> stop({bool discard = false}) async {
    _recording = false;
    return null;
  }

  @override
  Future<void> deleteFile(File? file) async {}

  @override
  Future<void> dispose() async {
    onFailure = null;
    _recording = false;
  }
}

/// A scriptable microphone permission, so a refusal can be tested without a
/// device and without the plugin's platform channel.
class _FakePermission {
  PermissionStatus status = PermissionStatus.granted;
  int settingsOpened = 0;

  MicrophonePermission build() => MicrophonePermission(
        check: () async => status,
        request: () async => status,
        openSettings: () async {
          settingsOpened++;
          return true;
        },
      );
}
