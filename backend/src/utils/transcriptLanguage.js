/**
 * Identifies which language a transcript is written in, from its script alone.
 *
 * Speech-to-text here is transcription, never translation: Telugu speech comes
 * back in Telugu script, Hindi in Devanagari, English in Latin letters. That
 * makes the script a complete and offline answer to "what language is this?" —
 * no model, no network call, and nothing that can quietly disagree with the
 * text the client is looking at.
 *
 * It is also the check that keeps the rule honest. A transcript that has been
 * translated into English *is* English by this measure, so a Telugu voice note
 * arriving as Latin text is visible as a defect rather than passing as a
 * successful transcription.
 *
 * Mirrors `lib/features/client/ai_smart_case/services/voice_language.dart` on
 * the app side; the two must agree on codes and on ranges.
 */

/** Unicode blocks, one per supported script. */
const TELUGU = [0x0c00, 0x0c7f];
const DEVANAGARI = [0x0900, 0x097f];

const SUPPORTED = new Set(["en", "hi", "te"]);

/**
 * The dominant script in `text`, as a language code, or "" when there are no
 * letters to judge by.
 *
 * Dominant rather than exclusive: real dictation carries English proper nouns,
 * section numbers and "FIR" inside a Telugu sentence, none of which make it an
 * English one. Only letters are counted, so digits and punctuation — shared by
 * every script — cannot swing the result.
 *
 * @param {string} text
 * @returns {"en"|"hi"|"te"|""}
 */
function detectTranscriptLanguage(text) {
  if (typeof text !== "string" || text.length === 0) return "";

  let latin = 0;
  let devanagari = 0;
  let telugu = 0;

  for (const char of text) {
    const code = char.codePointAt(0);
    if ((code >= 0x41 && code <= 0x5a) || (code >= 0x61 && code <= 0x7a)) latin++;
    else if (code >= DEVANAGARI[0] && code <= DEVANAGARI[1]) devanagari++;
    else if (code >= TELUGU[0] && code <= TELUGU[1]) telugu++;
  }

  if (!latin && !devanagari && !telugu) return "";
  if (telugu >= devanagari && telugu >= latin) return "te";
  if (devanagari >= latin) return "hi";
  return "en";
}

/**
 * Narrows a client-supplied language code to one the pipeline recognises, or ""
 * when it is absent or something else. Accepts `te`, `te-IN`, `te_IN`, `TE`.
 *
 * @param {unknown} code
 * @returns {"en"|"hi"|"te"|""}
 */
function normaliseLanguageCode(code) {
  if (typeof code !== "string") return "";
  const language = code.trim().toLowerCase().replace(/-/g, "_").split("_")[0];
  return SUPPORTED.has(language) ? language : "";
}

module.exports = { detectTranscriptLanguage, normaliseLanguageCode };
