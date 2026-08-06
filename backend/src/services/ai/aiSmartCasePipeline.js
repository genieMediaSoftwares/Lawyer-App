const fs = require("fs");
const AiSmartCaseSession = require("../../models/AiSmartCaseSession");
const ocrSanitizationService = require("./ocrSanitizationService");
const aiSmartIntakeService = require("./aiSmartIntakeService");
const gemini = require("./geminiClient");

/**
 * The AI Smart Case intake pipeline.
 *
 * Runs detached from the HTTP request that started it. The endpoint persists
 * the session and returns an id immediately; everything below happens after
 * the response has been sent, reporting each real transition over Socket.IO
 * and persisting the same state to the session document.
 *
 * Two rules govern this file:
 *
 *  1. Progress is only ever emitted from a point the pipeline has actually
 *     reached. There is no timer, no interpolation and no optimistic
 *     advancement — a client showing "Reading document 3 of 7" means document
 *     3 is genuinely being read right now.
 *
 *  2. The session document is written before the socket event, so a client
 *     that missed the event (backgrounded, reconnected, different device) sees
 *     identical state by fetching the session. The socket is an accelerator,
 *     never the source of truth.
 */

/**
 * Stage weights, in the order they run. `percent` is the cumulative weight of
 * completed stages plus the fraction of the current one that is genuinely
 * done, so the bar tracks real work rather than elapsed time.
 */
const PIPELINE_STAGES = [
  { id: "queued", label: "Preparing your documents", weight: 2 },
  { id: "ocr", label: "Reading documents", weight: 50 },
  { id: "transcribing", label: "Transcribing voice note", weight: 12 },
  { id: "extracting", label: "Extracting case details", weight: 28 },
  { id: "classifying", label: "Classifying the legal issue", weight: 8 },
  { id: "completed", label: "Analysis complete", weight: 0 },
];

const stageIndex = (id) => PIPELINE_STAGES.findIndex((s) => s.id === id);

/** Cumulative weight of every stage before `id`. */
const weightBefore = (id) =>
  PIPELINE_STAGES.slice(0, Math.max(0, stageIndex(id))).reduce((sum, s) => sum + s.weight, 0);

/**
 * How many documents are OCR'd at once.
 *
 * Set to 1 (sequential) to keep within Gemini per-second rate limits (2 RPS).
 */
const OCR_CONCURRENCY = 1;

/**
 * Total wall-clock budget for one intake. Past this the run is failed
 * deliberately with an explanation, instead of being killed anonymously by
 * Node's request timeout or leaving a session stuck in "processing" forever.
 */
const PIPELINE_BUDGET_MS = 8 * 60 * 1000;

/** A document with fewer readable characters than this needs vision help. */
const SPARSE_TEXT_THRESHOLD = 40;

class AiSmartCasePipeline {
  /**
   * @param {object} io  The Socket.IO server, from `app.get("io")`. Optional:
   *   the pipeline still runs and still persists progress without it.
   */
  constructor(io) {
    this.io = io;
  }

  /**
   * Persists progress and broadcasts it to the owning client.
   *
   * @param {object} session   The session document being advanced.
   * @param {string} stage     A PIPELINE_STAGES id.
   * @param {string} message   The line shown in the UI.
   * @param {object} [detail]  `{ current, total }` for repeated stages, and
   *   `fraction` (0-1) describing how far through the stage we are.
   */
  async report(session, stage, message, detail = {}) {
    const { current = null, total = null, fraction = 0 } = detail;

    const stageWeight = PIPELINE_STAGES[stageIndex(stage)]?.weight ?? 0;
    const percent = Math.min(
      100,
      Math.round(weightBefore(stage) + stageWeight * Math.min(1, Math.max(0, fraction)))
    );

    const progress = {
      stage,
      message,
      percent,
      current,
      total,
      updatedAt: new Date(),
    };

    // Persist first: the session is the source of truth a reconnecting client
    // reads, so it must never lag behind what was broadcast.
    try {
      await AiSmartCaseSession.updateOne({ _id: session._id }, { $set: { progress } });
    } catch (e) {
      console.error("Could not persist pipeline progress:", e.message);
    }

    this.emit(session.client, "analysis_progress", {
      sessionId: session._id.toString(),
      ...progress,
    });
  }

  /** Emits to the owning client's room on the authenticated /ai namespace. */
  emit(clientId, event, payload) {
    if (!this.io || !clientId) return;
    try {
      this.io.of("/ai").to(clientId.toString()).emit(event, payload);
    } catch (e) {
      console.error(`Could not emit ${event}:`, e.message);
    }
  }

  /**
   * Runs the whole intake. Never throws — a failure is recorded on the session
   * and pushed to the client as `analysis_failed`.
   *
   * @param {object} session        Freshly created "processing" session.
   * @param {object[]} documentFiles Multer files, already on disk.
   * @param {object|null} voiceFile  Multer file for the voice note, if any.
   * @param {string} typedDescription The client's own written notes.
   * @param {string} [liveVoiceTranscript] The transcript the client's device
   *   produced while they spoke, already reviewed and edited by them. When
   *   present it is used as-is and the transcription stage does no work.
   */
  async run({ session, documentFiles, voiceFile, typedDescription, liveVoiceTranscript = "" }) {
    const startedAt = Date.now();
    const overBudget = () => Date.now() - startedAt > PIPELINE_BUDGET_MS;

    try {
      await this.report(session, "queued", "Preparing your documents", { fraction: 1 });

      // ── 1. OCR every document ───────────────────────────────────────────
      const { ocrText, documentMetadata, sparseFiles, failures, fraudFlags, documentSummaries } =
        await this._readDocuments(session, documentFiles, overBudget);

      // ── 2. Voice note ───────────────────────────────────────────────────
      //
      // The client's device transcribes as they speak, so in the normal case
      // the text is already here and this stage is a formality. Only a device
      // without a speech recogniser reaches the transcription call below, and
      // only then does the client wait for it.
      let voiceTranscript = (liveVoiceTranscript || "").trim();
      let voiceTranscriptionFailed = false;
      let voiceTranscriptSource = voiceTranscript ? "live" : "none";

      if (voiceTranscript) {
        await this.report(session, "transcribing", "Using your voice note", { fraction: 1 });
      } else if (voiceFile) {
        if (overBudget()) {
          voiceTranscriptionFailed = true;
        } else {
          await this.report(session, "transcribing", "Transcribing your voice note", {
            fraction: 0,
          });
          const result = await this._transcribe(voiceFile);
          voiceTranscript = result.transcript;
          voiceTranscriptionFailed = result.failed;
          if (!result.failed && result.transcript) voiceTranscriptSource = "server";
        }
        await this.report(
          session,
          "transcribing",
          voiceTranscriptionFailed
            ? "Voice note could not be transcribed"
            : "Voice note transcribed",
          { fraction: 1 }
        );
      }

      // Nothing readable at all: fail honestly rather than inventing a case
      // out of a filename.
      if (!ocrText.trim() && !voiceTranscript.trim() && !typedDescription.trim()) {
        return this._fail(
          session,
          failures.length
            ? "We could not read any text from the document(s) you uploaded. Please upload a clearer copy, or describe your issue in writing, and try again."
            : "There was nothing to analyse. Please upload a readable document or describe your issue."
        );
      }

      if (overBudget()) {
        return this._fail(
          session,
          "Reading your documents took longer than expected and the analysis was stopped. Please try again with fewer or smaller files."
        );
      }

      // ── 3. Structured extraction ────────────────────────────────────────
      await this.report(session, "extracting", "Extracting case details", { fraction: 0 });

      const { extracted, warnings: extractionNotes } = await aiSmartIntakeService.extractCaseData({
        ocrText,
        voiceTranscript,
        typedDescription,
        documentMetadata,
        documentFiles,
        priorityFiles: sparseFiles,
      });

      await this.report(session, "extracting", "Case details extracted", { fraction: 1 });

      // ── 4. Classification result ────────────────────────────────────────
      await this.report(
        session,
        "classifying",
        extracted.category
          ? `Classified as ${extracted.category}${extracted.subType ? ` — ${extracted.subType}` : ""}`
          : "Could not classify the matter — you will choose a category",
        { fraction: 1 }
      );

      // The client's own words are the most trustworthy text available, so
      // they stand in when the model produced no description. This is not
      // fabrication: it is the client's own account, verbatim.
      if (!extracted.description) {
        extracted.description = typedDescription.trim() || voiceTranscript.trim();
      }

      const warnings = [
        ...failures.map((f) => `${f.name}: ${f.reason}`),
        ...fraudFlags,
        ...extractionNotes,
        ...(voiceTranscriptionFailed
          ? ["Your voice note could not be transcribed, so it was not used."]
          : []),
      ];

      const completed = await AiSmartCaseSession.findByIdAndUpdate(
        session._id,
        {
          $set: {
            status: "extracted",
            ocrExtractedText: ocrText,
            voiceTranscript,
            voiceTranscriptSource,
            voiceTranscriptionFailed,
            extractedData: extracted,
            warnings,
            progress: {
              stage: "completed",
              message: "Analysis complete",
              percent: 100,
              current: null,
              total: null,
              updatedAt: new Date(),
            },
          },
        },
        { new: true }
      );

      this.emit(session.client, "analysis_complete", {
        sessionId: session._id.toString(),
        extracted,
        uploadedDocuments: completed?.uploadedDocuments ?? [],
        voiceTranscript,
        voiceTranscriptSource,
        voiceTranscriptionFailed,
        extractionWarnings: warnings,
        documentSummaries,
      });

      // The client already has their result; transcribing the recording here
      // is for the record, not for them. Deliberately not awaited and
      // deliberately silent — a failure changes nothing they can see.
      if (voiceFile && voiceTranscriptSource === "live") {
        this._verifyVoiceInBackground(session, voiceFile);
      }

      return completed;
    } catch (error) {
      console.error("AI Smart Case pipeline error:", error);
      return this._fail(
        session,
        "Something went wrong while analysing your documents. Please try again."
      );
    }
  }

  /**
   * OCRs every uploaded document, in bounded-concurrency batches, reporting
   * after each one completes.
   */
  async _readDocuments(session, documentFiles, overBudget) {
    const total = documentFiles.length;

    let ocrText = "";
    const documentMetadata = [];
    const documentSummaries = [];
    const sparseFiles = [];
    const failures = [];
    const fraudFlags = [];

    let done = 0;

    for (let start = 0; start < total; start += OCR_CONCURRENCY) {
      const batch = documentFiles.slice(start, start + OCR_CONCURRENCY);

      const results = await Promise.all(
        batch.map(async (file) => {
          if (overBudget()) {
            return {
              file,
              result: {
                extractedText: "",
                ocrQuality: "Extraction Unavailable",
                fraudFlags: [],
                charCount: 0,
                extractionFailed: true,
                extractionError: "Skipped: the analysis ran out of time.",
              },
            };
          }

          const result = await ocrSanitizationService
            .extractText(file.path, file.mimetype, file.originalname)
            // One unreadable document must not fail the whole intake.
            .catch((err) => ({
              extractedText: "",
              ocrQuality: "Extraction Unavailable",
              fraudFlags: [],
              charCount: 0,
              extractionFailed: true,
              extractionError: err.message,
            }));

          return { file, result };
        })
      );

      for (const { file, result } of results) {
        done += 1;

        if (result.extractedText && result.extractedText.trim()) {
          ocrText += `\n\n--- DOCUMENT: ${file.originalname} ---\n${result.extractedText}`;
        }

        // Failed OCR, or so little text that the document is effectively
        // unrepresented — send the bytes to the model directly instead.
        if (result.extractionFailed || result.charCount < SPARSE_TEXT_THRESHOLD) {
          sparseFiles.push(file);
        }

        if (result.extractionFailed) {
          failures.push({
            name: file.originalname,
            reason: result.extractionError || "OCR service unavailable",
          });
        }

        if (result.fraudFlags?.length) fraudFlags.push(...result.fraudFlags);

        documentMetadata.push({
          name: file.originalname,
          size: `${(file.size / 1024).toFixed(1)} KB`,
          type: file.mimetype,
          ocrQuality: result.ocrQuality,
          charactersExtracted: result.charCount,
        });

        documentSummaries.push({
          name: file.originalname,
          ocrQuality: result.ocrQuality,
          charactersExtracted: result.charCount,
          failed: Boolean(result.extractionFailed),
        });

        await this.report(
          session,
          "ocr",
          total === 1
            ? `Read ${file.originalname}`
            : `Read document ${done} of ${total} — ${file.originalname}`,
          { current: done, total, fraction: done / total }
        );
      }
    }

    // Record the per-document OCR verdict on the session so the client sees the
    // same quality information the pipeline acted on.
    try {
      await AiSmartCaseSession.updateOne(
        { _id: session._id },
        {
          $set: documentSummaries.reduce((patch, summary, i) => {
            patch[`uploadedDocuments.${i}.ocrQuality`] = summary.ocrQuality;
            return patch;
          }, {}),
        }
      );
    } catch (e) {
      console.error("Could not persist OCR quality:", e.message);
    }

    return { ocrText, documentMetadata, sparseFiles, failures, fraudFlags, documentSummaries };
  }

  /**
   * Transcribes the uploaded audio after the analysis has already been
   * delivered, purely so the retained recording and the transcript the client
   * submitted can be compared later.
   *
   * Never awaited, never emitted, never turned into a warning: the client
   * reviewed and edited the live transcript themselves, so it stands regardless
   * of what this produces.
   */
  _verifyVoiceInBackground(session, voiceFile) {
    setImmediate(async () => {
      try {
        const { transcript, failed } = await this._transcribe(voiceFile);
        if (failed || !transcript) return;

        await AiSmartCaseSession.updateOne(
          { _id: session._id },
          { $set: { serverVoiceTranscript: transcript } }
        );
      } catch (err) {
        console.error("Background voice verification failed:", err.message);
      }
    });
  }

  /** Transcribes the voice note. Routed through geminiClient for failover. */
  async _transcribe(voiceFile) {
    try {
      const audioBase64 = fs.readFileSync(voiceFile.path).toString("base64");

      const { text } = await gemini.generate(
        [
          {
            inlineData: {
              mimeType: voiceFile.mimetype || "audio/mp4",
              data: audioBase64,
            },
          },
          {
            text:
              "Transcribe this voice description of a legal issue verbatim into English. " +
              "Return ONLY the plain transcript, with no commentary.",
          },
        ],
        { label: "smart-case:transcribe" }
      );

      return { transcript: text || "", failed: !text };
    } catch (err) {
      console.error("Voice transcription failed in intake:", err.message);
      return { transcript: "", failed: true };
    }
  }

  /** Marks the session failed, tells the client why, and returns it. */
  async _fail(session, reason) {
    const failed = await AiSmartCaseSession.findByIdAndUpdate(
      session._id,
      {
        $set: {
          status: "failed",
          failureReason: reason,
          progress: {
            stage: "failed",
            message: reason,
            percent: 100,
            current: null,
            total: null,
            updatedAt: new Date(),
          },
        },
      },
      { new: true }
    );

    this.emit(session.client, "analysis_failed", {
      sessionId: session._id.toString(),
      message: reason,
    });

    return failed;
  }
}

module.exports = { AiSmartCasePipeline, PIPELINE_STAGES, PIPELINE_BUDGET_MS };
