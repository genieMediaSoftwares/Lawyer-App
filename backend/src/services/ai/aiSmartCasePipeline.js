const fs = require("fs");
const AiSmartCaseSession = require("../../models/AiSmartCaseSession");
const ocrSanitizationService = require("./ocrSanitizationService");
const aiSmartIntakeService = require("./aiSmartIntakeService");
const gemini = require("./geminiClient");
const log = require("../../utils/aiLogger");
const {
  detectTranscriptLanguage,
  normaliseLanguageCode,
} = require("../../utils/transcriptLanguage");

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

/**
 * Per-step ceilings, enforced with a race rather than trusting the callee.
 *
 * The budget above used to be checked only *between* stages, which meant it
 * could not stop a stage that never returned. `geminiClient` walks up to five
 * models, twice, retrying 429s, at 60 seconds per attempt — arithmetic that
 * reaches twenty minutes for a single call. One such call therefore blew right
 * past the eight-minute budget, and because nothing else advanced the session,
 * it sat on "Extracting case details" until someone restarted the server.
 *
 * A step that exceeds its ceiling is abandoned and treated as having produced
 * nothing, which every caller below already handles.
 */
const OCR_STEP_TIMEOUT_MS = 150 * 1000;
const TRANSCRIBE_STEP_TIMEOUT_MS = 120 * 1000;
const EXTRACT_STEP_TIMEOUT_MS = 180 * 1000;

/** A document with fewer readable characters than this needs vision help. */
const SPARSE_TEXT_THRESHOLD = 40;

/**
 * What the model is told when it has to transcribe the audio itself — the path
 * taken only by devices with no usable speech recogniser for the client's
 * language.
 *
 * It previously read "transcribe this voice description of a legal issue
 * verbatim into English", and "verbatim into English" is a contradiction: a
 * client speaking Telugu cannot be quoted verbatim in English. The model
 * resolved it the way it was asked to, by translating, so the case was built
 * from an English paraphrase and the client's own words were never stored
 * anywhere. Transcribing in the spoken language and script is the fix; the
 * extraction step downstream reads Telugu and Hindi perfectly well and no
 * longer needs the input flattened for it.
 */
const TRANSCRIPTION_PROMPT =
  "Transcribe this voice description of a legal issue verbatim.\n" +
  "Write the transcript in the language that is actually spoken — do not translate it.\n" +
  "Use that language's own script: Telugu speech in Telugu script (తెలుగు), Hindi speech in " +
  "Devanagari script (देवनागरी), English speech in Latin letters. Never romanise or " +
  "transliterate Telugu or Hindi into English letters.\n" +
  "If the speaker mixes languages, keep each phrase in the language and script it was spoken in. " +
  "Legal terms said in English — FIR, IPC, BNS, CrPC, Section 138, High Court, bail, writ, " +
  "case numbers and dates — stay in English letters exactly as spoken, inside the surrounding " +
  "Telugu or Hindi sentence.\n" +
  "Return ONLY the plain transcript, with no commentary.";

/**
 * Names the language when the client picked one in the recorder, so the model
 * is told rather than left to infer.
 *
 * Detection is good but not free of doubt on a short or noisy clip, and a
 * client who explicitly chose తెలుగు has already answered the question. An
 * unrecognised or absent code adds nothing and leaves detection in charge —
 * which is exactly what Auto wants.
 */
const LANGUAGE_NAMES = { en: "English", hi: "Hindi", te: "Telugu" };

function promptFor(languageCode) {
  const name = LANGUAGE_NAMES[languageCode];
  if (!name) return TRANSCRIPTION_PROMPT;
  return (
    `The speaker has told us they are speaking ${name}. Transcribe in ${name}, ` +
    `in its own script.\n${TRANSCRIPTION_PROMPT}`
  );
}

/** Marker distinguishing "the step ran out of time" from "the step threw". */
class StepTimeoutError extends Error {
  constructor(label, ms) {
    super(`${label} exceeded ${Math.round(ms / 1000)}s`);
    this.name = "StepTimeoutError";
  }
}

/**
 * Resolves with [work]'s value, or rejects with a [StepTimeoutError] once [ms]
 * has passed.
 *
 * The underlying work is not cancellable — it is an in-flight `fetch` inside
 * geminiClient — so it keeps running to completion in the background and its
 * result is discarded. That is acceptable and deliberate: the alternative is a
 * pipeline that a single hung upstream call can stall indefinitely.
 */
function withTimeout(work, ms, label) {
  let timer;
  return Promise.race([
    Promise.resolve(work).finally(() => clearTimeout(timer)),
    new Promise((_, reject) => {
      timer = setTimeout(() => reject(new StepTimeoutError(label, ms)), ms);
      // Never hold the event loop open for a step nobody is waiting on.
      if (timer.unref) timer.unref();
    }),
  ]);
}

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
    //
    // A failed write is not fatal to the run, but it *is* fatal to the client's
    // view of it: the poll fallback reads this document, so a session whose
    // progress stops advancing looks abandoned to the stale-session sweep. Log
    // it loudly rather than swallowing it into a console.error nobody greps.
    try {
      await AiSmartCaseSession.updateOne({ _id: session._id }, { $set: { progress } });
    } catch (e) {
      log.error("pipeline:progress-persist-failed", e, { session: session._id, stage });
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
      // The socket is an accelerator, never the source of truth — the client's
      // poll still reconciles against the session document.
      log.error("pipeline:emit-failed", e, { event });
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
   * @param {string} [liveVoiceLanguage] ISO 639-1 code for the language that
   *   transcript is in, as detected on the device. Only ever a label: the
   *   transcript itself is stored and analysed exactly as the client left it.
   */
  async run({
    session,
    documentFiles,
    voiceFile,
    typedDescription,
    liveVoiceTranscript = "",
    liveVoiceLanguage = "",
  }) {
    const startedAt = Date.now();
    const overBudget = () => Date.now() - startedAt > PIPELINE_BUDGET_MS;

    // Hard stop. The stage-boundary `overBudget()` checks below cannot rescue a
    // run whose *current* stage has hung, and every step here calls out to a
    // network service that can. This watchdog fires regardless of where the run
    // is, marks the session failed and tells the client — the difference
    // between an intake that reports a timeout and one that spins forever.
    let watchdogFired = false;
    const watchdog = setTimeout(() => {
      watchdogFired = true;
      log.error("pipeline:watchdog-fired", new Error("pipeline exceeded budget"), {
        session: session._id,
        elapsedMs: Date.now() - startedAt,
      });
      this._fail(
        session,
        "The analysis took longer than expected and was stopped. Please try again with fewer or smaller documents."
      ).catch((e) => log.error("pipeline:watchdog-fail-write-failed", e));
    }, PIPELINE_BUDGET_MS + 15 * 1000);
    if (watchdog.unref) watchdog.unref();

    log.info("pipeline:start", {
      session: session._id,
      documents: documentFiles.length,
      voice: Boolean(voiceFile),
    });

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

      // The device's answer is preferred over our own reading of the script,
      // because the device knows which language it listened in — but a missing
      // or unrecognised code still resolves rather than being left blank.
      let voiceTranscriptLanguage = voiceTranscript
        ? normaliseLanguageCode(liveVoiceLanguage) ||
          detectTranscriptLanguage(voiceTranscript)
        : "";

      if (voiceTranscript) {
        await this.report(session, "transcribing", "Using your voice note", { fraction: 1 });
      } else if (voiceFile) {
        if (overBudget()) {
          voiceTranscriptionFailed = true;
        } else {
          await this.report(session, "transcribing", "Transcribing your voice note", {
            fraction: 0,
          });
          // Auto sends no code and detection decides; an explicit choice is
          // passed through so the model transcribes in the language the client
          // actually selected.
          const result = await this._transcribe(
            voiceFile,
            normaliseLanguageCode(liveVoiceLanguage)
          );
          voiceTranscript = result.transcript;
          voiceTranscriptionFailed = result.failed;
          if (!result.failed && result.transcript) {
            voiceTranscriptSource = "server";
            voiceTranscriptLanguage = result.language;
          }
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

      // Nothing readable from text-OCR: if all documents failed OCR and no text/voice was provided,
      // fail honestly. If valid scanned/image documents exist, proceed to structured extraction
      // with priorityFiles attached inline so Gemini Vision reads them.
      const hasFilesToProcess = Array.isArray(documentFiles) && documentFiles.length > 0;
      const allOcrFailed = failures.length === documentFiles.length && hasFilesToProcess;

      if ((!ocrText.trim() && !voiceTranscript.trim() && !typedDescription.trim() && !hasFilesToProcess) || allOcrFailed) {
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

      let extracted;
      let extractionNotes;
      try {
        ({ extracted, warnings: extractionNotes } = await withTimeout(
          aiSmartIntakeService.extractCaseData({
            ocrText,
            voiceTranscript,
            typedDescription,
            documentMetadata,
            documentFiles,
            priorityFiles: sparseFiles.length > 0 ? sparseFiles : documentFiles,
          }),
          EXTRACT_STEP_TIMEOUT_MS,
          "extraction"
        ));
      } catch (e) {
        // This is the one step with no useful degraded mode: without structured
        // fields there is nothing to pre-fill the form with. Fail with a
        // message the client can act on rather than letting the generic
        // handler below report "something went wrong".
        log.error("pipeline:extraction-failed", e, { session: session._id });
        return this._fail(
          session,
          e instanceof StepTimeoutError
            ? "Analysing your documents took longer than expected. Please try again, or with fewer documents."
            : "We could not extract case details from your documents. Please try again, or fill the form in manually."
        );
      }

      const hasContent = extracted && (
        Boolean(extracted.title) ||
        Boolean(extracted.description) ||
        Boolean(extracted.category) ||
        Boolean(extracted.summary) ||
        (Array.isArray(extracted.parties) && extracted.parties.length > 0)
      );

      if (!hasContent && !typedDescription.trim() && !voiceTranscript.trim()) {
        return this._fail(
          session,
          "We could not extract case details from the document(s) you uploaded. Please upload a clearer copy, or describe your issue in writing, and try again."
        );
      }

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

      // The watchdog may have already failed this session while extraction was
      // running. Writing "extracted" on top would leave the client holding an
      // `analysis_failed` it can never reconcile, so the filter refuses to
      // resurrect a run that has already been given up on. `status` is the
      // condition rather than a flag in this process, so a second worker or a
      // restarted server reaches the same conclusion.
      const completed = await AiSmartCaseSession.findOneAndUpdate(
        { _id: session._id, status: "processing" },
        {
          $set: {
            status: "extracted",
            ocrExtractedText: ocrText,
            voiceTranscript,
            voiceTranscriptLanguage,
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

      if (!completed) {
        log.warn("pipeline:completed-after-terminal", {
          session: session._id,
          watchdogFired,
        });
        return AiSmartCaseSession.findById(session._id);
      }

      this.emit(session.client, "analysis_complete", {
        sessionId: session._id.toString(),
        extracted,
        uploadedDocuments: completed.uploadedDocuments ?? [],
        voiceTranscript,
        voiceTranscriptLanguage,
        voiceTranscriptSource,
        voiceTranscriptionFailed,
        extractionWarnings: warnings,
        documentSummaries,
      });

      if (voiceFile && voiceTranscriptSource === "live") {
        this._verifyVoiceInBackground(session, voiceFile);
      }

      log.info("pipeline:complete", {
        session: session._id,
        elapsedMs: Date.now() - startedAt,
        category: extracted.category || "unclassified",
        warnings: warnings.length,
      });

      return completed;
    } catch (error) {
      log.error("pipeline:unhandled", error, { session: session._id });
      return this._fail(
        session,
        "Something went wrong while analysing your documents. Please try again."
      );
    } finally {
      clearTimeout(watchdog);
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

          // Bounded per document. Without a ceiling one pathological scan —
          // a 200-page PDF, or a Gemini call that hangs behind retries — held
          // the whole intake, and every other document behind it, for as long
          // as it liked.
          const result = await withTimeout(
            ocrSanitizationService.extractText(file.path, file.mimetype, file.originalname),
            OCR_STEP_TIMEOUT_MS,
            `ocr(${file.originalname})`
          )
            // One unreadable document must not fail the whole intake.
            .catch((err) => {
              log.warn("pipeline:ocr-failed", {
                session: session._id,
                name: file.originalname,
                error: err.message,
              });
              return {
                extractedText: "",
                ocrQuality: "Extraction Unavailable",
                fraudFlags: [],
                charCount: 0,
                extractionFailed: true,
                extractionError:
                  err instanceof StepTimeoutError
                    ? "Reading this document took too long and it was skipped."
                    : err.message,
              };
            });

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
    if (documentSummaries.length > 0) {
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
        // Cosmetic only — the extraction itself is unaffected.
        log.warn("pipeline:ocr-quality-persist-failed", {
          session: session._id,
          error: e.message,
        });
      }
    }

    return { ocrText, documentMetadata, sparseFiles, failures, fraudFlags, documentSummaries };
  }

  /**
   * Transcribes retained audio *after* the client already has their result, so
   * the server's own reading can be compared with the one their device
   * produced. Never substituted for it, and never surfaced — see
   * `serverVoiceTranscript` on the session.
   *
   * The opening `/**` above used to have no closing `*​/`, which commented the
   * whole method away: the call in `run` then threw `is not a function`, the
   * run's own catch turned that into `analysis_failed`, and a client whose
   * analysis had just completed successfully was told it had gone wrong.
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
        log.warn("pipeline:background-voice-verification-failed", { error: err.message });
      }
    });
  }

  /**
   * Transcribes the voice note. Routed through geminiClient for failover.
   */
  async _transcribe(voiceFile, languageCode = "") {
    try {
      if (!voiceFile.path || !fs.existsSync(voiceFile.path)) {
        log.warn("pipeline:voice-missing", { path: voiceFile.path });
        return { transcript: "", failed: true };
      }

      // Async read: the sync form blocked the event loop for the whole file on
      // a server also serving every other request.
      const audioBase64 = (await fs.promises.readFile(voiceFile.path)).toString("base64");

      const { text } = await withTimeout(
        gemini.generate(
          [
            {
              inlineData: {
                mimeType: voiceFile.mimetype || "audio/mp4",
                data: audioBase64,
              },
            },
            { text: promptFor(languageCode) },
          ],
          { label: "smart-case:transcribe" }
        ),
        TRANSCRIBE_STEP_TIMEOUT_MS,
        "transcription"
      );

      const transcript = text || "";
      return {
        transcript,
        // The script the model actually produced, not the language it was
        // asked for. A stated language that the transcript contradicts is
        // worth knowing about; asserting the request back would hide it.
        language: detectTranscriptLanguage(transcript),
        failed: !text,
      };
    } catch (err) {
      log.warn("pipeline:transcription-failed", { error: err.message });
      return { transcript: "", language: "", failed: true };
    }
  }

  /**
   * Marks the session failed, tells the client why, and returns it.
   *
   * Guarded on `status: "processing"` so it cannot overwrite a run that already
   * finished — the watchdog and the run body can both reach here, and a late
   * failure landing on a completed session would have shown the client an error
   * for an analysis they already had the result of.
   *
   * Never throws: it is called from `catch` blocks and from a timer callback,
   * where a rejection has nowhere to go.
   */
  async _fail(session, reason) {
    try {
      const failed = await AiSmartCaseSession.findOneAndUpdate(
        { _id: session._id, status: "processing" },
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

      if (!failed) {
        // Already terminal. Say nothing to the client: they have the real
        // outcome already.
        log.warn("pipeline:fail-after-terminal", { session: session._id, reason });
        return AiSmartCaseSession.findById(session._id);
      }

      log.warn("pipeline:failed", { session: session._id, reason });

      this.emit(session.client, "analysis_failed", {
        sessionId: session._id.toString(),
        message: reason,
      });

      return failed;
    } catch (e) {
      log.error("pipeline:fail-write-failed", e, { session: session._id });
      // The client still hears about it; the stale-session sweep will clean the
      // record up even though this write did not land.
      this.emit(session.client, "analysis_failed", {
        sessionId: session._id.toString(),
        message: reason,
      });
      return null;
    }
  }
}

module.exports = {
  AiSmartCasePipeline,
  PIPELINE_STAGES,
  PIPELINE_BUDGET_MS,
  StepTimeoutError,
};
