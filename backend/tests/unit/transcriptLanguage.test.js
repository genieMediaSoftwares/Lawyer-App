const {
  detectTranscriptLanguage,
  normaliseLanguageCode,
} = require("../../src/utils/transcriptLanguage");

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
    expect(detectTranscriptLanguage("naaku aasthi case gurinchi sahayam")).toBe("en");
  });

  it("keeps an English term inside an Indian-language sentence in place", () => {
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

    expect(normaliseLanguageCode("ta_IN")).toBe("");
    expect(normaliseLanguageCode("")).toBe("");
    expect(normaliseLanguageCode(undefined)).toBe("");
    expect(normaliseLanguageCode(42)).toBe("");
  });
});
