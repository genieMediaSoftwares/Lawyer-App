import 'package:flutter_test/flutter_test.dart';

import 'package:law/features/client/ai_smart_case/services/voice_language.dart';

/// Script is the evidence that a voice note was *transcribed* rather than
/// translated: Telugu speech that comes back in Latin letters has been through
/// a translation or a transliteration, whatever the pipeline claims about it.
/// These tests pin the detection every other layer relies on to say so.
void main() {
  const telugu = 'నాకు నా ఆస్తి కేసు గురించి సహాయం కావాలి';
  const hindi = 'मुझे अपने संपत्ति मामले के बारे में मदद चाहिए';
  const english = 'I need help with my property case';

  group('script detection', () {
    test('each language is recognised from its own script', () {
      expect(VoiceLanguage.scriptOf(english), VoiceScript.latin);
      expect(VoiceLanguage.scriptOf(hindi), VoiceScript.devanagari);
      expect(VoiceLanguage.scriptOf(telugu), VoiceScript.telugu);
    });

    test('detect maps a transcript to the language it is written in', () {
      expect(VoiceLanguage.detect(english)?.code, 'en');
      expect(VoiceLanguage.detect(hindi)?.code, 'hi');
      expect(VoiceLanguage.detect(telugu)?.code, 'te');
    });

    test('a Telugu transcript is never read as English', () {
      expect(VoiceLanguage.detect(telugu)?.code, isNot('en'));
      expect(VoiceLanguage.telugu.matchesScriptOf(telugu), isTrue);

      // What a translation layer produces. It must not pass as Telugu.
      expect(VoiceLanguage.telugu.matchesScriptOf(english), isFalse);
    });

    test('a Hindi transcript is never read as English', () {
      expect(VoiceLanguage.detect(hindi)?.code, isNot('en'));
      expect(VoiceLanguage.hindi.matchesScriptOf(hindi), isTrue);
      expect(VoiceLanguage.hindi.matchesScriptOf(english), isFalse);
    });

    test('romanised Telugu is caught, not accepted as Telugu', () {
      // A transliteration: the words are Telugu, the letters are not. This is
      // the failure that looks most like success, so it is called out by name.
      const romanised = 'naaku naa aasthi case gurinchi sahayam kavali';
      expect(VoiceLanguage.scriptOf(romanised), VoiceScript.latin);
      expect(VoiceLanguage.telugu.matchesScriptOf(romanised), isFalse);
    });

    test('romanised Hindi is caught, not accepted as Hindi', () {
      const romanised = 'mujhe apne sampatti mamle ke bare mein madad chahiye';
      expect(VoiceLanguage.scriptOf(romanised), VoiceScript.latin);
      expect(VoiceLanguage.hindi.matchesScriptOf(romanised), isFalse);
    });

    test('an English word inside a Telugu sentence does not make it English', () {
      // Real dictation: "FIR" and "Section 138" are said in English by a client
      // speaking Telugu, and rendering them in Telugu script would itself be a
      // translation. The sentence is still Telugu.
      const mixed = 'నా FIR లో Section 138 గురించి సహాయం కావాలి';
      expect(VoiceLanguage.detect(mixed)?.code, 'te');
      expect(VoiceLanguage.telugu.matchesScriptOf(mixed), isTrue);
    });

    test('digits and punctuation alone identify nothing', () {
      expect(VoiceLanguage.scriptOf('  138/2024 — ...  '), VoiceScript.unknown);
      expect(VoiceLanguage.detect(''), isNull);

      // Nothing to disagree with is not a mismatch; otherwise every silent
      // recording would be reported as the wrong language.
      expect(VoiceLanguage.telugu.matchesScriptOf(''), isTrue);
    });
  });

  group('language lookup', () {
    test('accepts every shape a locale id arrives in', () {
      for (final code in ['te', 'te_IN', 'te-IN', 'TE_in']) {
        expect(VoiceLanguage.forCode(code)?.code, 'te', reason: code);
      }
      expect(VoiceLanguage.forCode('hi_IN')?.code, 'hi');
      expect(VoiceLanguage.forCode('en_US')?.code, 'en');
    });

    test('an unsupported or absent language is null, not English', () {
      // Silently resolving to English is the defect this whole change removes;
      // the caller must be able to see that there is no answer.
      expect(VoiceLanguage.forCode('ta_IN'), isNull);
      expect(VoiceLanguage.forCode(null), isNull);
      expect(VoiceLanguage.forCode(''), isNull);
    });

    test('every supported language carries its own locale candidates only', () {
      for (final language in VoiceLanguage.all) {
        expect(language.localeCandidates, isNotEmpty);
        for (final candidate in language.localeCandidates) {
          expect(
            VoiceLanguage.forCode(candidate)?.code,
            language.code,
            reason: '$candidate must not offer a recogniser another language',
          );
        }
      }
    });
  });
}
