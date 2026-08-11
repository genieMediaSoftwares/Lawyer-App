import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

import 'package:law/features/client/ai_smart_case/services/live_transcription_service.dart';
import 'package:law/features/client/ai_smart_case/services/microphone_permission.dart';
import 'package:law/features/client/ai_smart_case/services/voice_language.dart';

/// The voice note is only as good as what survives a real recogniser's
/// behaviour, and platform recognisers do not behave like one long stream:
/// they end a session on every silence, on a time limit, and on errors that
/// mean nothing more than "say that again". These tests pin the three things
/// that behaviour must not be allowed to break.
void main() {
  late _FakeSpeechPlatform platform;
  late SpeechToText speech;
  late LiveTranscriptionService service;
  late _FakePermission permission;

  setUp(() {
    platform = _FakeSpeechPlatform();
    SpeechToTextPlatform.instance = platform;
    permission = _FakePermission();
    // A private instance rather than the `SpeechToText()` singleton, so one
    // test's initialisation cannot leak into the next.
    speech = SpeechToText.withMethodChannel();
    service = LiveTranscriptionService(
      speech: speech,
      permission: permission.build(),
    );
  });

  tearDown(() async => service.dispose());

  test('words recognised across several sessions form one transcript', () async {
    final seen = <String>[];
    service.onTranscript = seen.add;

    expect(await service.start(), isTrue);

    platform.emitResult('the landlord changed the locks', isFinal: true);
    // The platform ends the session on its own — a silence, or its per-session
    // time limit. The service must treat that as a pause, not as the end.
    platform.endSession();
    await _settle();

    expect(platform.listenCalls, 2, reason: 'listening resumed by itself');

    platform.emitResult('on the third of March', isFinal: true);

    expect(
      service.transcript,
      'the landlord changed the locks on the third of March',
    );
    expect(seen, isNotEmpty, reason: 'partials reach the UI as they arrive');
  });

  test('a silence timeout never reaches the UI or clears the transcript', () async {
    VoiceTranscriptionFailure? surfaced;
    service.onFailure = (f) => surfaced = f;

    await service.start();
    platform.emitResult('my tenancy started in 2019', isFinal: true);

    // What Android reports for "nothing was said just then".
    platform.emitError('error_speech_timeout', permanent: false);
    await _settle();

    expect(surfaced, isNull, reason: 'an ordinary pause is not an error');
    expect(service.transcript, 'my tenancy started in 2019');
    expect(service.isListening, isTrue);
  });

  test('a permanent error ends the session and keeps what was said', () async {
    VoiceTranscriptionFailure? surfaced;
    service.onFailure = (f) => surfaced = f;

    await service.start();
    platform.emitResult('the notice arrived last week', isFinal: true);

    platform.emitError('error_network', permanent: true);
    await _settle();

    expect(surfaced?.fault, VoiceTranscriptionFault.network);
    expect(surfaced?.message, contains('internet connection'));
    expect(service.isListening, isFalse);
    expect(
      service.transcript,
      'the notice arrived last week',
      reason: 'a failure must never cost the client the words they already said',
    );
  });

  test('stop returns the transcript without waiting on the platform', () async {
    await service.start();
    platform.emitResult('there is a boundary dispute', isFinal: true);

    // The platform sends nothing further — no trailing final result. stop must
    // still return promptly with what it has, which is what lets the UI show an
    // editable transcript the moment the client taps Stop.
    final settled = await service.stop().timeout(const Duration(seconds: 2));

    expect(settled, 'there is a boundary dispute');
    expect(service.isListening, isFalse);
  });

  test('an existing transcript is carried forward when recording resumes', () async {
    await service.start(seed: 'edited text from before');
    platform.emitResult('and one more thing', isFinal: true);

    expect(service.transcript, 'edited text from before and one more thing');
  });

  test('the requested language is used when the device has it', () async {
    await service.start(preferredLocales: VoiceLanguage.hindi.localeCandidates);
    expect(platform.lastLocaleId, 'hi_IN');
  });

  test('English speech is transcribed as English, as it always was', () async {
    await service.start(preferredLocales: VoiceLanguage.english.localeCandidates);
    expect(platform.lastLocaleId, 'en_IN');

    platform.emitResult('I need help with my property case', isFinal: true);

    expect(service.transcript, 'I need help with my property case');
    expect(service.detectedLanguage?.code, 'en');
  });

  test('Telugu speech stays in Telugu script and is labelled Telugu', () async {
    await service.start(preferredLocales: VoiceLanguage.telugu.localeCandidates);
    expect(platform.lastLocaleId, 'te_IN');

    const spoken = 'నాకు నా ఆస్తి కేసు గురించి సహాయం కావాలి';
    platform.emitResult(spoken, isFinal: true);

    expect(service.transcript, spoken, reason: 'the words are not rewritten');
    expect(service.detectedLanguage?.code, 'te');
    // Neither translated into English nor spelled out in English letters.
    expect(RegExp(r'[A-Za-z]').hasMatch(service.transcript), isFalse);
  });

  test('Hindi speech stays in Devanagari and is labelled Hindi', () async {
    await service.start(preferredLocales: VoiceLanguage.hindi.localeCandidates);
    expect(platform.lastLocaleId, 'hi_IN');

    const spoken = 'मुझे अपने संपत्ति मामले के बारे में मदद चाहिए';
    platform.emitResult(spoken, isFinal: true);

    expect(service.transcript, spoken);
    expect(service.detectedLanguage?.code, 'hi');
    expect(RegExp(r'[A-Za-z]').hasMatch(service.transcript), isFalse);
  });

  test('a language the device lacks is refused, never swapped for English',
      () async {
    // The device has English and Hindi installed, but no Telugu pack — the
    // exact configuration that used to hand a Telugu speaker the English
    // recogniser, which then produced English words from Telugu sounds.
    platform.supportedLocales = const [
      'en_IN:English (India)',
      'hi_IN:Hindi (India)',
    ];

    VoiceTranscriptionFailure? surfaced;
    service.onFailure = (f) => surfaced = f;

    final started =
        await service.start(preferredLocales: VoiceLanguage.telugu.localeCandidates);

    expect(started, isFalse);
    expect(surfaced?.fault, VoiceTranscriptionFault.languageUnavailable);
    expect(surfaced?.message, contains('Telugu'));

    // Nothing was recorded in another language behind the client's back.
    expect(platform.listenCalls, 0);
    expect(platform.lastLocaleId, isNull);
    expect(service.isListening, isFalse);
  });

  test('an unsupported language mid-session is reported, not worked around',
      () async {
    VoiceTranscriptionFailure? surfaced;
    service.onFailure = (f) => surfaced = f;

    await service.start(preferredLocales: VoiceLanguage.telugu.localeCandidates);
    platform.emitError('error_language_unavailable', permanent: true);
    await _settle();

    expect(surfaced?.fault, VoiceTranscriptionFault.languageUnavailable);
    expect(service.isListening, isFalse);
  });

  test('no preference still uses the system locale, as before', () async {
    // The only path on which the device gets to choose. Callers that name a
    // language are answered about that language or not at all.
    await service.start();
    expect(platform.lastLocaleId, 'en_IN');
  });

  test('no recogniser is reported as unavailable, not as a crash', () async {
    platform.initializeResult = false;

    VoiceTranscriptionFailure? surfaced;
    service.onFailure = (f) => surfaced = f;

    expect(await service.start(), isFalse);
    expect(surfaced?.fault, VoiceTranscriptionFault.unavailable);
    expect(service.isListening, isFalse);
  });

  test('a granted microphone starts listening', () async {
    permission.status = PermissionStatus.granted;

    VoiceTranscriptionFailure? surfaced;
    service.onFailure = (f) => surfaced = f;

    expect(await service.start(), isTrue);
    expect(surfaced, isNull);
    expect(service.isListening, isTrue);
    expect(permission.requests, 0, reason: 'already granted, so no prompt');
  });

  test('a refused microphone is reported as a permission problem, and asked '
      'for rather than assumed', () async {
    permission.status = PermissionStatus.denied;
    permission.afterRequest = PermissionStatus.denied;

    VoiceTranscriptionFailure? surfaced;
    service.onFailure = (f) => surfaced = f;

    expect(await service.start(), isFalse);

    expect(permission.requests, 1, reason: 'the OS prompt is still worth showing');
    expect(surfaced?.fault, VoiceTranscriptionFault.permissionDenied);
    expect(surfaced?.message, contains('Microphone access'));
    // A refusal is not a missing recogniser, and must not send the client to a
    // Settings page they can still avoid.
    expect(surfaced?.needsSettings, isFalse);
    expect(surfaced?.shouldFallBackToRecording, isFalse);
    expect(platform.initializeCalls, 0, reason: 'never initialised unpermitted');
  });

  test('a permanently denied microphone offers Settings and does not re-prompt',
      () async {
    permission.status = PermissionStatus.permanentlyDenied;

    VoiceTranscriptionFailure? surfaced;
    service.onFailure = (f) => surfaced = f;

    expect(await service.start(), isFalse);

    expect(surfaced?.fault, VoiceTranscriptionFault.permissionPermanentlyDenied);
    expect(surfaced?.needsSettings, isTrue);
    expect(surfaced?.message, contains('Settings'));
    // Prompting again shows nothing at all, which reads as a dead button.
    expect(permission.requests, 0);

    expect(await service.openAppSettings(), isTrue);
    expect(permission.settingsOpened, 1);
  });

  test('a restricted microphone is explained without offering Settings',
      () async {
    permission.status = PermissionStatus.restricted;

    VoiceTranscriptionFailure? surfaced;
    service.onFailure = (f) => surfaced = f;

    await service.start();

    expect(surfaced?.fault, VoiceTranscriptionFault.permissionRestricted);
    // The client cannot grant it themselves, so Settings would be a dead end.
    expect(surfaced?.needsSettings, isFalse);
  });

  test('a recogniser that throws on start is a start-up failure, not a missing '
      'microphone', () async {
    platform.initializeThrows = true;

    VoiceTranscriptionFailure? surfaced;
    service.onFailure = (f) => surfaced = f;

    expect(await service.start(), isFalse);

    expect(surfaced?.fault, VoiceTranscriptionFault.initialisationFailed);
    expect(surfaced?.message, isNot(contains('microphone')));
    // The microphone works, so the voice note carries on by recording.
    expect(surfaced?.shouldFallBackToRecording, isTrue);
  });
}

/// A scriptable microphone permission.
class _FakePermission {
  PermissionStatus status = PermissionStatus.granted;

  /// What a prompt resolves to. Defaults to whatever the status already is.
  PermissionStatus? afterRequest;

  int requests = 0;
  int settingsOpened = 0;

  MicrophonePermission build() => MicrophonePermission(
        check: () async => status,
        request: () async {
          requests++;
          return status = afterRequest ?? status;
        },
        openSettings: () async {
          settingsOpened++;
          return true;
        },
      );
}

/// Lets pending timers — the restart delay in particular — run.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 400));

/// Stands in for the device recogniser, driven by the test rather than by
/// speech.
class _FakeSpeechPlatform extends SpeechToTextPlatform {
  bool initializeResult = true;
  bool permission = true;

  /// Makes `initialize` throw, which is a recogniser that exists but could not
  /// be started — not a device without one.
  bool initializeThrows = false;
  int initializeCalls = 0;

  int listenCalls = 0;
  String? lastLocaleId;
  bool listening = false;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<bool> initialize({
    debugLogging = false,
    List<SpeechConfigOption>? options,
  }) async {
    initializeCalls++;
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

  /// What the device has installed. Mutable so a test can take a language
  /// away, which is the interesting case — most Indian devices ship without a
  /// Telugu recognition pack.
  List<String> supportedLocales = const [
    'en_IN:English (India)',
    'hi_IN:Hindi (India)',
    'te_IN:Telugu (India)',
  ];

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

  /// The recogniser closing a session by itself, as it does on every silence
  /// and at its own time limit.
  void endSession() {
    listening = false;
    onStatus?.call('done');
  }
}
