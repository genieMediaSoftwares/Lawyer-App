/**
 * Fault-tolerance tests for the AI Smart Case pipeline.
 *
 * The pipeline runs detached from the request that started it, so nothing about
 * its failure modes is visible to a client, to a request log or to a response
 * status code. These tests pin the behaviours the client's processing screen
 * depends on: that the run always reaches a terminal state, that a hung
 * upstream call cannot leave a session in "processing" forever, and that a late
 * failure cannot overwrite a result the client already has.
 */

jest.mock("../../src/models/AiSmartCaseSession");
jest.mock("../../src/services/ai/ocrSanitizationService");
jest.mock("../../src/services/ai/aiSmartIntakeService");
jest.mock("../../src/services/ai/geminiClient");

const AiSmartCaseSession = require("../../src/models/AiSmartCaseSession");
const ocrSanitizationService = require("../../src/services/ai/ocrSanitizationService");
const aiSmartIntakeService = require("../../src/services/ai/aiSmartIntakeService");
const { AiSmartCasePipeline } = require("../../src/services/ai/aiSmartCasePipeline");

/** Minimal stand-in for the session document the controller hands the pipeline. */
function makeSession() {
  return { _id: "sess-1", client: "client-1" };
}

/** A multer file, as the upload middleware produces it. */
function makeFile(name = "fir.pdf") {
  return {
    path: `/tmp/${name}`,
    mimetype: "application/pdf",
    originalname: name,
    size: 1024,
  };
}

/** Captures every socket emission so assertions can read what the client saw. */
function makeIo() {
  const emitted = [];
  return {
    emitted,
    of: () => ({
      to: () => ({
        emit: (event, payload) => emitted.push({ event, payload }),
      }),
    }),
  };
}

const okOcr = {
  extractedText: "FIR No. 42/2024 registered at Banjara Hills police station.",
  ocrQuality: "Good",
  fraudFlags: [],
  charCount: 60,
  extractionFailed: false,
  extractionError: null,
};

const okExtraction = {
  extracted: { title: "Theft complaint", description: "…", category: "Criminal Law" },
  warnings: [],
};

beforeEach(() => {
  jest.clearAllMocks();

  AiSmartCaseSession.updateOne.mockResolvedValue({ modifiedCount: 1 });
  // Default: the session is still "processing", so terminal writes are accepted.
  AiSmartCaseSession.findOneAndUpdate.mockImplementation(async (_filter, update) => ({
    _id: "sess-1",
    uploadedDocuments: [],
    status: update.$set.status,
    failureReason: update.$set.failureReason,
  }));
  AiSmartCaseSession.findById.mockResolvedValue({ _id: "sess-1", status: "extracted" });

  ocrSanitizationService.extractText.mockResolvedValue(okOcr);
  aiSmartIntakeService.extractCaseData.mockResolvedValue(okExtraction);
});

describe("AI Smart Case pipeline", () => {
  it("completes a healthy run and tells the client once", async () => {
    const io = makeIo();
    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session: makeSession(),
      documentFiles: [makeFile()],
      voiceFile: null,
      typedDescription: "",
    });

    const completions = io.emitted.filter((e) => e.event === "analysis_complete");
    const failures = io.emitted.filter((e) => e.event === "analysis_failed");

    expect(completions).toHaveLength(1);
    expect(failures).toHaveLength(0);
    expect(completions[0].payload.sessionId).toBe("sess-1");
  });

  it("reports progress only for stages it actually reached", async () => {
    const io = makeIo();
    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session: makeSession(),
      documentFiles: [makeFile("a.pdf"), makeFile("b.pdf")],
      voiceFile: null,
      typedDescription: "",
    });

    const stages = io.emitted
      .filter((e) => e.event === "analysis_progress")
      .map((e) => e.payload.stage);

    // No voice note was supplied, so "transcribing" must never be claimed.
    expect(stages).not.toContain("transcribing");
    expect(stages).toContain("ocr");
    expect(stages).toContain("extracting");

    // Percent is monotonic: the bar can never run backwards.
    const percents = io.emitted
      .filter((e) => e.event === "analysis_progress")
      .map((e) => e.payload.percent);
    expect([...percents].sort((a, b) => a - b)).toEqual(percents);
  });

  it("fails the session rather than hanging when extraction never returns", async () => {
    // A Gemini call that never resolves. Before the per-step timeout, this run
    // sat on "Extracting case details" until the process was restarted, and the
    // client polled a "processing" session forever.
    aiSmartIntakeService.extractCaseData.mockImplementation(() => new Promise(() => {}));

    const io = makeIo();
    const pipeline = new AiSmartCasePipeline(io);

    jest.useFakeTimers();
    const run = pipeline.run({
      session: makeSession(),
      documentFiles: [makeFile()],
      voiceFile: null,
      typedDescription: "",
    });

    // Let the OCR stage's real promises settle, then jump past the extraction
    // step ceiling.
    await jest.advanceTimersByTimeAsync(1);
    await jest.advanceTimersByTimeAsync(200 * 1000);
    await run;
    jest.useRealTimers();

    const failures = io.emitted.filter((e) => e.event === "analysis_failed");
    expect(failures).toHaveLength(1);
    expect(failures[0].payload.message).toMatch(/longer than expected/i);
  }, 20000);

  it("keeps going when one document cannot be read", async () => {
    ocrSanitizationService.extractText
      .mockRejectedValueOnce(new Error("corrupt PDF"))
      .mockResolvedValueOnce(okOcr);

    const io = makeIo();
    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session: makeSession(),
      documentFiles: [makeFile("broken.pdf"), makeFile("good.pdf")],
      voiceFile: null,
      typedDescription: "",
    });

    const completions = io.emitted.filter((e) => e.event === "analysis_complete");
    expect(completions).toHaveLength(1);
    // The unreadable document is named, not silently dropped.
    expect(completions[0].payload.extractionWarnings.join(" ")).toMatch(/broken\.pdf/);
  });

  const failedOcr = {
    ...okOcr,
    extractedText: "",
    charCount: 0,
    extractionFailed: true,
    extractionError: "OCR service unavailable",
    ocrQuality: "Extraction Unavailable",
  };

  it("tries vision on a document whose text extraction failed", async () => {
    // A scan whose text layer will not read is exactly what vision is for, so
    // the file itself is handed to extraction rather than the run being
    // abandoned. It must go as bytes, not as a filename: inventing a case from
    // "fir.pdf" is the failure this guards.
    ocrSanitizationService.extractText.mockResolvedValue(failedOcr);

    const io = makeIo();
    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session: makeSession(),
      documentFiles: [makeFile()],
      voiceFile: null,
      typedDescription: "",
    });

    expect(aiSmartIntakeService.extractCaseData).toHaveBeenCalledTimes(1);
    const call = aiSmartIntakeService.extractCaseData.mock.calls[0][0];
    expect(call.ocrText).toBe("");
    expect(call.priorityFiles).toEqual([expect.objectContaining({ path: expect.any(String) })]);
  });

  it("fails honestly when vision also produces nothing", async () => {
    ocrSanitizationService.extractText.mockResolvedValue(failedOcr);
    aiSmartIntakeService.extractCaseData.mockResolvedValue({
      extracted: { title: "", description: "", category: null, summary: "", parties: [] },
      warnings: [],
    });

    const io = makeIo();
    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session: makeSession(),
      documentFiles: [makeFile()],
      voiceFile: null,
      typedDescription: "",
    });

    expect(io.emitted.filter((e) => e.event === "analysis_failed")).toHaveLength(1);
    expect(io.emitted.filter((e) => e.event === "analysis_complete")).toHaveLength(0);
  });

  it("analyses the voice note when every document failed to read", async () => {
    // The regression this exists for: a client recorded a voice note, their
    // scan would not read, and the run was abandoned with "we could not read
    // any text from the document(s) you uploaded" — discarding the spoken
    // account that had already been transcribed one stage earlier.
    ocrSanitizationService.extractText.mockResolvedValue(failedOcr);

    const io = makeIo();
    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session: makeSession(),
      documentFiles: [makeFile()],
      voiceFile: null,
      liveVoiceTranscript: "My husband is abusing me and I want to file for divorce.",
      typedDescription: "",
    });

    expect(aiSmartIntakeService.extractCaseData).toHaveBeenCalledTimes(1);
    expect(aiSmartIntakeService.extractCaseData.mock.calls[0][0].voiceTranscript).toMatch(/divorce/);
    expect(io.emitted.filter((e) => e.event === "analysis_complete")).toHaveLength(1);
    expect(io.emitted.filter((e) => e.event === "analysis_failed")).toHaveLength(0);
  });

  it("analyses written notes when every document failed to read", async () => {
    ocrSanitizationService.extractText.mockResolvedValue(failedOcr);

    const io = makeIo();
    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session: makeSession(),
      documentFiles: [makeFile()],
      voiceFile: null,
      typedDescription: "The builder has not given possession of my flat for two years.",
    });

    expect(aiSmartIntakeService.extractCaseData).toHaveBeenCalledTimes(1);
    expect(io.emitted.filter((e) => e.event === "analysis_complete")).toHaveLength(1);
  });

  it("never shows a raw provider error to the client", async () => {
    ocrSanitizationService.extractText.mockResolvedValue({
      ...failedOcr,
      extractionError:
        'gemini-1.5-pro: HTTP 404 { "error": { "code": 404, "message": "models/gemini-1.5-pro is not found for API version v1beta, or is not supported for generateContent. Call ModelService.ListModels"',
    });

    const io = makeIo();
    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session: makeSession(),
      documentFiles: [makeFile()],
      voiceFile: null,
      typedDescription: "My landlord will not return my deposit.",
    });

    const completion = io.emitted.find((e) => e.event === "analysis_complete");
    const shown = completion.payload.extractionWarnings.join(" ");
    expect(shown).toMatch(/fir\.pdf/);
    expect(shown).not.toMatch(/HTTP 404|gemini|ListModels|generateContent/i);
  });

  it("does not claim a voice note failed when there was no voice note", async () => {
    const io = makeIo();
    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session: makeSession(),
      documentFiles: [makeFile()],
      voiceFile: null,
      typedDescription: "",
    });

    const completion = io.emitted.find((e) => e.event === "analysis_complete");
    expect(completion.payload.extractionWarnings.join(" ")).not.toMatch(/voice note/i);
  });

  it("does not overwrite a session that already reached a terminal state", async () => {
    // Simulates the watchdog having already failed this run: the guarded write
    // matches nothing, so the late completion must not be broadcast.
    AiSmartCaseSession.findOneAndUpdate.mockResolvedValue(null);

    const io = makeIo();
    const pipeline = new AiSmartCasePipeline(io);

    await pipeline.run({
      session: makeSession(),
      documentFiles: [makeFile()],
      voiceFile: null,
      typedDescription: "",
    });

    expect(io.emitted.filter((e) => e.event === "analysis_complete")).toHaveLength(0);
  });

  it("never throws, even when every database write fails", async () => {
    AiSmartCaseSession.updateOne.mockRejectedValue(new Error("mongo down"));
    AiSmartCaseSession.findOneAndUpdate.mockRejectedValue(new Error("mongo down"));
    AiSmartCaseSession.findById.mockRejectedValue(new Error("mongo down"));

    const pipeline = new AiSmartCasePipeline(makeIo());

    await expect(
      pipeline.run({
        session: makeSession(),
        documentFiles: [makeFile()],
        voiceFile: null,
        typedDescription: "",
      })
    ).resolves.not.toThrow();
  });

  it("survives having no Socket.IO server at all", async () => {
    const pipeline = new AiSmartCasePipeline(null);

    await expect(
      pipeline.run({
        session: makeSession(),
        documentFiles: [makeFile()],
        voiceFile: null,
        typedDescription: "",
      })
    ).resolves.toBeTruthy();
  });
});
