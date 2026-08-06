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
    jest.spyOn(fs, "readFileSync").mockReturnValue(Buffer.from("audio"));
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

    await new Promise((resolve) => setImmediate(resolve));
    await new Promise((resolve) => setImmediate(resolve));

    expect(gemini.generate).toHaveBeenCalledTimes(1);

    const verification = sessionUpdates.find((u) => "serverVoiceTranscript" in u);
    expect(verification.serverVoiceTranscript).toBe("server side transcript");

    // Silent: the client's transcript stands and no further event is sent.
    expect(emitted.filter((e) => e.event === "analysis_complete")).toHaveLength(1);
    expect(emitted.some((e) => e.event === "analysis_failed")).toBe(false);
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
