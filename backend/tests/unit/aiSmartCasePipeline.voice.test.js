const fs = require("fs");

jest.mock("../../src/models/AiSmartCaseSession");
jest.mock("../../src/services/ai/ocrSanitizationService");
jest.mock("../../src/services/ai/aiSmartIntakeService");
jest.mock("../../src/services/ai/geminiClient");

const AiSmartCaseSession = require("../../src/models/AiSmartCaseSession");
const ocrSanitizationService = require("../../src/services/ai/ocrSanitizationService");
const aiSmartIntakeService = require("../../src/services/ai/aiSmartIntakeService");
const gemini = require("../../src/services/ai/geminiClient");
const { AiSmartCasePipeline } = require("../../src/services/ai/aiSmartCasePipeline");

/**
 * The voice note is transcribed on the client's device while they speak, so the
 * transcript arrives with the upload. These tests pin what that must and must
 * not change about the pipeline:
 *
 *  * the analysis never waits on transcription when a transcript is supplied;
 *  * a device that cannot transcribe still gets the old server-side path;
 *  * the spoken and typed accounts stay separate inputs, neither duplicated
 *    into the other; and
 *  * OCR and the progress events the client subscribes to are untouched.
 */
describe("AI Smart Case pipeline — voice note", () => {
  let emitted;
  let io;
  let sessionUpdates;

  const session = { _id: "session-1", client: "client-1" };

  const documentFile = {
    path: "/tmp/fir.pdf",
    mimetype: "application/pdf",
    originalname: "fir.pdf",
    size: 2048,
  };

  const voiceFile = { path: "/tmp/note.m4a", mimetype: "audio/mp4" };

  beforeEach(() => {
    jest.clearAllMocks();

    emitted = [];
    sessionUpdates = [];

    io = {
      of: () => ({
        to: () => ({
          emit: (event, payload) => emitted.push({ event, payload }),
        }),
      }),
    };

    AiSmartCaseSession.updateOne.mockImplementation(async (_query, update) => {
      sessionUpdates.push(update.$set);
      return { acknowledged: true };
    });
    AiSmartCaseSession.findByIdAndUpdate.mockImplementation(async (_id, update) => {
      sessionUpdates.push(update.$set);
      return { ...update.$set, uploadedDocuments: [] };
    });
    // The completion write is guarded on `status: "processing"`, so it goes
    // through `findOneAndUpdate` rather than by id. Without this the pipeline
    // read every run as one that had already been given up on, returned early,
    // and emitted no `analysis_complete` at all — which is what most of the
    // expectations below are reading.
    AiSmartCaseSession.findOneAndUpdate.mockImplementation(async (_query, update) => {
      sessionUpdates.push(update.$set);
      return { ...update.$set, uploadedDocuments: [] };
    });

    ocrSanitizationService.extractText.mockResolvedValue({
      extractedText: "FIR No. 123/2024 registered at Banjara Hills PS",
      ocrQuality: "Good",
      fraudFlags: [],
      charCount: 48,
    });

    aiSmartIntakeService.extractCaseData.mockResolvedValue({
      extracted: { title: "FIR quashing", description: "", category: "Criminal" },
      warnings: [],
    });

    gemini.generate.mockResolvedValue({ text: "server side transcript" });

    // The voice note is a path that exists only on the client's machine, and
    // the pipeline reads it asynchronously. Mocking `readFileSync` alone left
    // `_transcribe` bailing out at its `existsSync` guard, so the server-side
    // transcription path was never actually entered by any test here.
    jest.spyOn(fs, "existsSync").mockReturnValue(true);
    jest.spyOn(fs.promises, "readFile").mockResolvedValue(Buffer.from("audio"));
  });

  afterEach(() => jest.restoreAllMocks());

  const progressStages = () =>
    emitted
      .filter((e) => e.event === "analysis_progress")
      .map((e) => e.payload.stage);

  it("uses the live transcript and never waits on transcription", async () => {
    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session,
      documentFiles: [documentFile],
      voiceFile: null,
      typedDescription: "the deposit was never returned",
      liveVoiceTranscript: "my landlord kept the deposit after I moved out",
    });

    expect(gemini.generate).not.toHaveBeenCalled();

    const call = aiSmartIntakeService.extractCaseData.mock.calls[0][0];
    expect(call.voiceTranscript).toBe("my landlord kept the deposit after I moved out");
    expect(call.typedDescription).toBe("the deposit was never returned");
  });

  it("keeps the spoken and typed accounts as separate, unduplicated inputs", async () => {
    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session,
      documentFiles: [documentFile],
      voiceFile: null,
      typedDescription: "typed account",
      liveVoiceTranscript: "spoken account",
    });

    const call = aiSmartIntakeService.extractCaseData.mock.calls[0][0];
    expect(call.typedDescription).not.toContain("spoken account");
    expect(call.voiceTranscript).not.toContain("typed account");

    const completion = emitted.find((e) => e.event === "analysis_complete");
    // One transcript on the session and in the completion payload, not the
    // spoken text repeated into the description as well.
    expect(completion.payload.voiceTranscript).toBe("spoken account");
    expect(completion.payload.voiceTranscriptSource).toBe("live");
  });

  it("still transcribes server-side when the device could not", async () => {
    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session,
      documentFiles: [documentFile],
      voiceFile,
      typedDescription: "",
      liveVoiceTranscript: "",
    });

    expect(gemini.generate).toHaveBeenCalledTimes(1);

    const call = aiSmartIntakeService.extractCaseData.mock.calls[0][0];
    expect(call.voiceTranscript).toBe("server side transcript");

    const completion = emitted.find((e) => e.event === "analysis_complete");
    expect(completion.payload.voiceTranscriptSource).toBe("server");
  });

  it("records a failed server transcription as a warning, as before", async () => {
    gemini.generate.mockResolvedValue({ text: "" });

    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session,
      documentFiles: [documentFile],
      voiceFile,
      typedDescription: "",
      liveVoiceTranscript: "",
    });

    const completion = emitted.find((e) => e.event === "analysis_complete");
    expect(completion.payload.voiceTranscriptionFailed).toBe(true);
    expect(completion.payload.extractionWarnings).toContain(
      "Your voice note could not be transcribed, so it was not used."
    );
  });

  it("verifies retained audio after the client already has the result", async () => {
    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session,
      documentFiles: [documentFile],
      voiceFile,
      typedDescription: "",
      liveVoiceTranscript: "what the client actually reviewed",
    });

    const completion = emitted.find((e) => e.event === "analysis_complete");
    expect(completion.payload.voiceTranscript).toBe("what the client actually reviewed");
    // Nothing has been transcribed at the point the client is told the analysis
    // is done — the verification is scheduled for after.
    expect(gemini.generate).not.toHaveBeenCalled();

    // The verification is detached with `setImmediate` and then reads the file
    // and calls the model, so it settles several ticks later — a fixed pair of
    // ticks raced it and usually lost.
    for (let i = 0; i < 20 && gemini.generate.mock.calls.length === 0; i++) {
      await new Promise((resolve) => setImmediate(resolve));
    }

    expect(gemini.generate).toHaveBeenCalledTimes(1);

    const verification = sessionUpdates.find((u) => "serverVoiceTranscript" in u);
    expect(verification.serverVoiceTranscript).toBe("server side transcript");

    // Silent: the client's transcript stands and no further event is sent.
    expect(emitted.filter((e) => e.event === "analysis_complete")).toHaveLength(1);
    expect(emitted.some((e) => e.event === "analysis_failed")).toBe(false);
  });

  it("asks for a transcription in the spoken language, not a translation", async () => {
    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session,
      documentFiles: [documentFile],
      voiceFile,
      typedDescription: "",
      liveVoiceTranscript: "",
    });

    const parts = gemini.generate.mock.calls[0][0];
    const prompt = parts.find((p) => typeof p.text === "string").text;

    // The instruction that caused the defect read "verbatim into English", so
    // nothing may ask for an English rendering of non-English speech again.
    // "English letters" is allowed only where it is forbidden — hence the
    // prohibitions asserted below rather than a blanket ban on the word.
    expect(prompt).not.toMatch(/verbatim into English/i);
    expect(prompt).not.toMatch(/English transcript/i);
    expect(prompt).not.toMatch(/translate[^.]*into/i);

    expect(prompt).toMatch(/do not translate/i);
    expect(prompt).toMatch(/never romanise or transliterate/i);
    expect(prompt).toMatch(/Telugu/);
    expect(prompt).toMatch(/Devanagari/);
  });

  it("keeps a server-transcribed Telugu note in Telugu and labels it", async () => {
    const telugu = "నాకు నా ఆస్తి కేసు గురించి సహాయం కావాలి";
    gemini.generate.mockResolvedValue({ text: telugu });

    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session,
      documentFiles: [documentFile],
      voiceFile,
      typedDescription: "",
      liveVoiceTranscript: "",
    });

    const call = aiSmartIntakeService.extractCaseData.mock.calls[0][0];
    // The extraction reads the client's own words, not an English rendering
    // of them made on the way in.
    expect(call.voiceTranscript).toBe(telugu);
    expect(/[A-Za-z]/.test(call.voiceTranscript)).toBe(false);

    const completion = emitted.find((e) => e.event === "analysis_complete");
    expect(completion.payload.voiceTranscript).toBe(telugu);
    expect(completion.payload.voiceTranscriptLanguage).toBe("te");
  });

  it("keeps a live Hindi transcript exactly as the client reviewed it", async () => {
    const hindi = "मुझे अपने संपत्ति मामले के बारे में मदद चाहिए";

    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session,
      documentFiles: [documentFile],
      voiceFile: null,
      typedDescription: "",
      liveVoiceTranscript: hindi,
      liveVoiceLanguage: "hi",
    });

    expect(gemini.generate).not.toHaveBeenCalled();

    const call = aiSmartIntakeService.extractCaseData.mock.calls[0][0];
    expect(call.voiceTranscript).toBe(hindi);
    expect(/[A-Za-z]/.test(call.voiceTranscript)).toBe(false);

    const completion = emitted.find((e) => e.event === "analysis_complete");
    expect(completion.payload.voiceTranscriptLanguage).toBe("hi");
  });

  it("labels a transcript from an app build that sent no language code", async () => {
    const telugu = "నా ఇంటి మీద కేసు నడుస్తోంది";

    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session,
      documentFiles: [documentFile],
      voiceFile: null,
      typedDescription: "",
      liveVoiceTranscript: telugu,
    });

    const completion = emitted.find((e) => e.event === "analysis_complete");
    expect(completion.payload.voiceTranscriptLanguage).toBe("te");
    expect(completion.payload.voiceTranscript).toBe(telugu);
  });

  it("still labels an English voice note English, unchanged", async () => {
    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session,
      documentFiles: [documentFile],
      voiceFile: null,
      typedDescription: "",
      liveVoiceTranscript: "my landlord kept the deposit",
      liveVoiceLanguage: "en",
    });

    const completion = emitted.find((e) => e.event === "analysis_complete");
    expect(completion.payload.voiceTranscript).toBe("my landlord kept the deposit");
    expect(completion.payload.voiceTranscriptLanguage).toBe("en");
    expect(completion.payload.voiceTranscriptSource).toBe("live");
  });

  it("leaves the language empty when nothing could be transcribed", async () => {
    gemini.generate.mockResolvedValue({ text: "" });

    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session,
      documentFiles: [documentFile],
      voiceFile,
      typedDescription: "the deposit was never returned",
      liveVoiceTranscript: "",
    });

    const completion = emitted.find((e) => e.event === "analysis_complete");
    expect(completion.payload.voiceTranscriptionFailed).toBe(true);
    expect(completion.payload.voiceTranscriptLanguage).toBe("");
    expect(completion.payload.voiceTranscript).toBe("");
  });

  it("names the language the client chose, so it is not left to detection", async () => {
    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session,
      documentFiles: [documentFile],
      voiceFile,
      typedDescription: "",
      liveVoiceTranscript: "",
      liveVoiceLanguage: "te",
    });

    const parts = gemini.generate.mock.calls[0][0];
    const prompt = parts.find((part) => typeof part.text === "string").text;

    expect(prompt).toMatch(/speaking Telugu/);
    expect(prompt).toMatch(/Transcribe in Telugu/);
    // Still a transcription, never a translation.
    expect(prompt).toMatch(/do not translate/i);
  });

  it("leaves detection in charge when the client chose Auto", async () => {
    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session,
      documentFiles: [documentFile],
      voiceFile,
      typedDescription: "",
      liveVoiceTranscript: "",
      liveVoiceLanguage: "",
    });

    const parts = gemini.generate.mock.calls[0][0];
    const prompt = parts.find((part) => typeof part.text === "string").text;

    // Auto means the audio decides, so no language is asserted at the model.
    expect(prompt).not.toMatch(/has told us they are speaking/);
    expect(prompt).toMatch(/language that is actually spoken/i);
  });

  it("asks for English legal terms to survive inside Indian-language speech", async () => {
    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session,
      documentFiles: [documentFile],
      voiceFile,
      typedDescription: "",
      liveVoiceTranscript: "",
    });

    const parts = gemini.generate.mock.calls[0][0];
    const prompt = parts.find((part) => typeof part.text === "string").text;

    expect(prompt).toMatch(/FIR/);
    expect(prompt).toMatch(/IPC/);
    expect(prompt).toMatch(/BNS/);
    expect(prompt).toMatch(/Section 138/);
  });

  it("carries mixed Telugu and English speech through untouched", async () => {
    const mixed = "\u0c28\u0c3e FIR \u0c32\u0c4b Section 138 \u0c17\u0c41\u0c30\u0c3f\u0c02\u0c1a\u0c3f";
    gemini.generate.mockResolvedValue({ text: mixed });

    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session,
      documentFiles: [documentFile],
      voiceFile,
      typedDescription: "",
      liveVoiceTranscript: "",
    });

    const call = aiSmartIntakeService.extractCaseData.mock.calls[0][0];
    expect(call.voiceTranscript).toBe(mixed);
    expect(call.voiceTranscript).toContain("FIR");
    expect(call.voiceTranscript).toContain("Section 138");

    const completion = emitted.find((e) => e.event === "analysis_complete");
    // English legal terms inside a Telugu sentence do not make it English.
    expect(completion.payload.voiceTranscriptLanguage).toBe("te");
  });

  it("carries mixed Hindi and English speech through untouched", async () => {
    const mixed = "\u092e\u0947\u0930\u0940 FIR \u092e\u0947\u0902 IPC Section 420";

    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session,
      documentFiles: [documentFile],
      voiceFile: null,
      typedDescription: "",
      liveVoiceTranscript: mixed,
      liveVoiceLanguage: "hi",
    });

    const call = aiSmartIntakeService.extractCaseData.mock.calls[0][0];
    expect(call.voiceTranscript).toBe(mixed);
    expect(call.voiceTranscript).toContain("IPC");

    const completion = emitted.find((e) => e.event === "analysis_complete");
    expect(completion.payload.voiceTranscriptLanguage).toBe("hi");
  });

  it("reports the script produced, not the language requested", async () => {
    // The client asked for Telugu and the model answered in English. The
    // session must record what actually came back, or a translation would be
    // filed under the language it was translated out of.
    gemini.generate.mockResolvedValue({ text: "I need help with my property case" });

    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session,
      documentFiles: [documentFile],
      voiceFile,
      typedDescription: "",
      liveVoiceTranscript: "",
      liveVoiceLanguage: "te",
    });

    const completion = emitted.find((e) => e.event === "analysis_complete");
    expect(completion.payload.voiceTranscriptLanguage).toBe("en");
  });

  it("leaves OCR and the progress sequence unchanged", async () => {
    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session,
      documentFiles: [documentFile, { ...documentFile, originalname: "notice.pdf" }],
      voiceFile: null,
      typedDescription: "",
      liveVoiceTranscript: "a spoken account",
    });

    expect(ocrSanitizationService.extractText).toHaveBeenCalledTimes(2);

    expect(progressStages()).toEqual([
      "queued",
      "ocr",
      "ocr",
      "transcribing",
      "extracting",
      "extracting",
      "classifying",
    ]);

    // Percentages still come from real stage weights and never go backwards.
    const percents = emitted
      .filter((e) => e.event === "analysis_progress")
      .map((e) => e.payload.percent);
    expect(percents).toEqual([...percents].sort((a, b) => a - b));

    const call = aiSmartIntakeService.extractCaseData.mock.calls[0][0];
    expect(call.ocrText).toContain("FIR No. 123/2024");
  });

  it("fails honestly when there is nothing readable at all", async () => {
    ocrSanitizationService.extractText.mockResolvedValue({
      extractedText: "",
      ocrQuality: "Extraction Unavailable",
      fraudFlags: [],
      charCount: 0,
      extractionFailed: true,
      extractionError: "unreadable",
    });

    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session,
      documentFiles: [documentFile],
      voiceFile: null,
      typedDescription: "",
      liveVoiceTranscript: "",
    });

    expect(aiSmartIntakeService.extractCaseData).not.toHaveBeenCalled();
    expect(emitted.some((e) => e.event === "analysis_failed")).toBe(true);
  });

  it("a live transcript alone is enough to analyse an unreadable document", async () => {
    ocrSanitizationService.extractText.mockResolvedValue({
      extractedText: "",
      ocrQuality: "Extraction Unavailable",
      fraudFlags: [],
      charCount: 0,
      extractionFailed: true,
      extractionError: "unreadable",
    });

    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session,
      documentFiles: [documentFile],
      voiceFile: null,
      typedDescription: "",
      liveVoiceTranscript: "the shop refused to honour the warranty",
    });

    expect(aiSmartIntakeService.extractCaseData).toHaveBeenCalled();
    expect(emitted.some((e) => e.event === "analysis_failed")).toBe(false);
  });
});
