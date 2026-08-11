const {
  detectTranscriptLanguage,
  normaliseLanguageCode,
} = require("../../src/utils/transcriptLanguage");

/**
 * The script a transcript is written in is the only evidence that it was
 * transcribed rather than translated. These tests pin that reading, and the
 * one conclusion the pipeline must never reach: that Telugu or Hindi speech
 * came back as English.
 */
describe("transcript language detection", () => {
  const telugu = "నాకు నా ఆస్తి కేసు గురించి సహాయం కావాలి";
  const hindi = "मुझे अपने संपत्ति मामले के बारे में मदद चाहिए";
  const english = "I need help with my property case";

  it("reads each language from its own script", () => {
    expect(detectTranscriptLanguage(english)).toBe("en");
    expect(detectTranscriptLanguage(hindi)).toBe("hi");
    expect(detectTranscriptLanguage(telugu)).toBe("te");
  });

  it("never reads Telugu or Hindi as English", () => {
    expect(detectTranscriptLanguage(telugu)).not.toBe("en");
    expect(detectTranscriptLanguage(hindi)).not.toBe("en");
  });

  it("does not mistake a romanised transcript for the real thing", () => {
    // Telugu words in English letters. It is a transliteration, and calling it
    // Telugu would let the failure through unnoticed.
    expect(detectTranscriptLanguage("naaku aasthi case gurinchi sahayam")).toBe("en");
  });

  it("keeps an English term inside an Indian-language sentence in place", () => {
    // A client dictating in Telugu still says "FIR" and "Section 138".
    expect(detectTranscriptLanguage("నా FIR లో Section 138 గురించి")).toBe("te");
    expect(detectTranscriptLanguage("मेरी FIR में Section 138 के बारे में")).toBe("hi");
  });

  it("returns nothing when there are no letters to judge by", () => {
    expect(detectTranscriptLanguage("")).toBe("");
    expect(detectTranscriptLanguage("138/2024 — ...")).toBe("");
    expect(detectTranscriptLanguage(null)).toBe("");
    expect(detectTranscriptLanguage(undefined)).toBe("");
  });

  it("narrows a client-supplied code without inventing one", () => {
    expect(normaliseLanguageCode("te")).toBe("te");
    expect(normaliseLanguageCode("te_IN")).toBe("te");
    expect(normaliseLanguageCode("te-IN")).toBe("te");
    expect(normaliseLanguageCode("HI_in")).toBe("hi");

    // Unknown or absent must not silently resolve to English.
    expect(normaliseLanguageCode("ta_IN")).toBe("");
    expect(normaliseLanguageCode("")).toBe("");
    expect(normaliseLanguageCode(undefined)).toBe("");
    expect(normaliseLanguageCode(42)).toBe("");
  });
});
