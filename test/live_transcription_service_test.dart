import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

import 'package:law/features/client/ai_smart_case/services/live_transcription_service.dart';

/// The voice note is only as good as what survives a real recogniser's
/// behaviour, and platform recognisers do not behave like one long stream:
/// they end a session on every silence, on a time limit, and on errors that
/// mean nothing more than "say that again". These tests pin the three things
/// that behaviour must not be allowed to break.
void main() {
  late _FakeSpeechPlatform platform;
  late SpeechToText speech;
  late LiveTranscriptionService service;

  setUp(() {
    platform = _FakeSpeechPlatform();
    SpeechToTextPlatform.instance = platform;
    // A private instance rather than the `SpeechToText()` singleton, so one
    // test's initialisation cannot leak into the next.
    speech = SpeechToText.withMethodChannel();
    service = LiveTranscriptionService(speech: speech);
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
    await service.start(preferredLocales: const ['hi_IN', 'en_IN']);
    expect(platform.lastLocaleId, 'hi_IN');
  });

  test('a language the device lacks falls back to the next choice', () async {
    await service.start(preferredLocales: const ['te_IN', 'en_IN']);
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

  test('a refused microphone is reported as a permission problem', () async {
    platform.initializeResult = false;
    platform.permission = false;

    VoiceTranscriptionFailure? surfaced;
    service.onFailure = (f) => surfaced = f;

    await service.start();

    expect(surfaced?.fault, VoiceTranscriptionFault.permissionDenied);
    expect(surfaced?.message, contains('Microphone access'));
  });
}

/// Lets pending timers — the restart delay in particular — run.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 400));

/// Stands in for the device recogniser, driven by the test rather than by
/// speech.
class _FakeSpeechPlatform extends SpeechToTextPlatform {
  bool initializeResult = true;
  bool permission = true;

  int listenCalls = 0;
  String? lastLocaleId;
  bool listening = false;

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
    lastLocaleId = localeId;
    listening = true;
    onStatus?.call('listening');
    return true;
  }

  @override
  Future<void> stop() async => listening = false;

  @override
  Future<void> cancel() async => listening = false;

  @override
  Future<List<dynamic>> locales() async => <String>[
        'en_IN:English (India)',
        'hi_IN:Hindi (India)',
      ];

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
