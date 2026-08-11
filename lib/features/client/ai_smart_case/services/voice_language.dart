/// Languages the voice note can be spoken in, and how to tell them apart from
/// the text itself.
///
/// The rule this file exists to enforce is that speech-to-text is
/// *transcription*, never translation: what a client says in Telugu comes back
/// in Telugu script, what they say in Hindi comes back in Devanagari, and only
/// English comes back in Latin letters. Two things follow from that:
///
///  1. A recogniser has to be told which language to listen for — no platform
///     recogniser detects it — so each language carries the locale ids worth
///     trying, best first, and nothing here ever falls back across languages.
///     Falling back from Telugu to `en_IN` is exactly how Telugu speech ended
///     up as English words.
///  2. Once there is text, the script it is written in identifies the language
///     with no model and no network call. That is what lets the pipeline label
///     a transcript, and what lets the recorder notice that a recogniser
///     answered in the wrong script instead of quietly accepting it.
library;

/// The writing systems the three supported languages use.
enum VoiceScript {
  /// A–Z / a–z. English.
  latin,

  /// U+0900–U+097F. Hindi.
  devanagari,

  /// U+0C00–U+0C7F. Telugu.
  telugu,

  /// No letters at all — digits, punctuation, or nothing.
  unknown,
}

/// A language the voice note supports, with everything needed to ask a
/// recogniser for it and to recognise its output.
class VoiceLanguage {
  /// ISO 639-1 code, and the value persisted with the transcript.
  final String code;

  /// English name, for messages the client reads.
  final String label;

  /// The script a correct transcript in this language is written in.
  final VoiceScript script;

  /// Locale ids to offer the device recogniser, best first.
  ///
  /// Regional variants come before the bare language tag because devices
  /// overwhelmingly carry the regional form (`te_IN`, not `te`).
  final List<String> localeCandidates;

  const VoiceLanguage._({
    required this.code,
    required this.label,
    required this.script,
    required this.localeCandidates,
  });

  static const english = VoiceLanguage._(
    code: 'en',
    label: 'English',
    script: VoiceScript.latin,
    localeCandidates: ['en_IN', 'en_US', 'en_GB', 'en'],
  );

  static const hindi = VoiceLanguage._(
    code: 'hi',
    label: 'Hindi',
    script: VoiceScript.devanagari,
    localeCandidates: ['hi_IN', 'hi'],
  );

  static const telugu = VoiceLanguage._(
    code: 'te',
    label: 'Telugu',
    script: VoiceScript.telugu,
    localeCandidates: ['te_IN', 'te'],
  );

  static const all = <VoiceLanguage>[english, hindi, telugu];

  /// The language for an app locale or language code, or null if it is not one
  /// the voice note supports.
  ///
  /// Accepts anything a locale id can look like — `te`, `te_IN`, `te-IN`,
  /// `TE_in` — because this is fed from the app locale, from `.env` and from
  /// the platform's own locale list.
  static VoiceLanguage? forCode(String? code) {
    if (code == null) return null;
    final language = code.toLowerCase().replaceAll('-', '_').split('_').first;
    if (language.isEmpty) return null;
    for (final candidate in all) {
      if (candidate.code == language) return candidate;
    }
    return null;
  }

  /// The dominant script in [text].
  ///
  /// Dominant rather than exclusive: real dictation mixes in English proper
  /// nouns, section numbers and "FIR", none of which make a Telugu sentence
  /// English. Only letters are counted, so punctuation and digits — which every
  /// script shares — cannot swing the answer.
  static VoiceScript scriptOf(String text) {
    var latin = 0;
    var devanagari = 0;
    var telugu = 0;

    for (final rune in text.runes) {
      if ((rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A)) {
        latin++;
      } else if (rune >= 0x0900 && rune <= 0x097F) {
        devanagari++;
      } else if (rune >= 0x0C00 && rune <= 0x0C7F) {
        telugu++;
      }
    }

    if (latin == 0 && devanagari == 0 && telugu == 0) return VoiceScript.unknown;
    if (telugu >= devanagari && telugu >= latin) return VoiceScript.telugu;
    if (devanagari >= latin) return VoiceScript.devanagari;
    return VoiceScript.latin;
  }

  /// The language [text] is written in, judged by its script alone, or null
  /// when there are no letters to judge by.
  ///
  /// This is the detection the rest of the pipeline relies on. It cannot be
  /// fooled by a translation layer: text that has been translated into English
  /// *is* English by this measure, which is why the layers that used to
  /// translate had to stop rather than be labelled around.
  static VoiceLanguage? detect(String text) {
    switch (scriptOf(text)) {
      case VoiceScript.telugu:
        return telugu;
      case VoiceScript.devanagari:
        return hindi;
      case VoiceScript.latin:
        return english;
      case VoiceScript.unknown:
        return null;
    }
  }

  /// True when [text] is written in the script this language uses.
  ///
  /// Empty or letterless text is not a mismatch — there is nothing to disagree
  /// with, and treating it as one would flag every silent recording.
  bool matchesScriptOf(String text) {
    final actual = scriptOf(text);
    return actual == VoiceScript.unknown || actual == script;
  }

  @override
  String toString() => 'VoiceLanguage($code)';
}

/// What the client picked in the voice note's language selector.
///
/// Either a named language or "Auto", and the difference decides which engine
/// runs. A named language can be given to the on-device recogniser, so speech
/// appears as words while they talk. "Auto" cannot: no platform recogniser
/// detects a language for itself, it must be told one. So Auto records the
/// audio and lets the backend — which does detect — transcribe it, in whatever
/// script the detected language uses.
class VoiceLanguageChoice {
  /// Null for Auto.
  final VoiceLanguage? language;

  const VoiceLanguageChoice._(this.language);

  static const auto = VoiceLanguageChoice._(null);

  static const english = VoiceLanguageChoice._(VoiceLanguage.english);
  static const telugu = VoiceLanguageChoice._(VoiceLanguage.telugu);
  static const hindi = VoiceLanguageChoice._(VoiceLanguage.hindi);

  /// The selector's options, in the order they are shown.
  static const options = <VoiceLanguageChoice>[auto, english, telugu, hindi];

  /// The choice for a language, or [auto] when there is none.
  static VoiceLanguageChoice of(VoiceLanguage? language) {
    if (language == null) return auto;
    for (final option in options) {
      if (option.language?.code == language.code) return option;
    }
    return auto;
  }

  bool get isAuto => language == null;

  /// The label on the chip. Each language names itself in its own script, so a
  /// Telugu speaker can find it without reading English.
  String get label {
    switch (language?.code) {
      case 'en':
        return 'English';
      case 'te':
        return 'తెలుగు';
      case 'hi':
        return 'हिन्दी';
      default:
        return 'Auto';
    }
  }

  /// The code carried with the transcript. Empty for Auto, where only the
  /// backend can say what was spoken.
  String get code => language?.code ?? '';

  /// Locale ids for the on-device recogniser — one language's worth, never a
  /// cross-language chain. Empty for Auto, which does not use the recogniser.
  List<String> get localeCandidates => language?.localeCandidates ?? const [];
}
