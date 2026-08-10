const path = require("path");
const fs = require("fs");
const mongoose = require("mongoose");
const ApiResponse = require("../../config/ApiResponse");
const AiSmartCaseSession = require("../../models/AiSmartCaseSession");
const Document = require("../../models/Document");
const {
  AiSmartCasePipeline,
  PIPELINE_BUDGET_MS,
} = require("../../services/ai/aiSmartCasePipeline");
const log = require("../../utils/aiLogger");

/** Repo root, used to turn an absolute upload path into a served URL. */
const PROJECT_ROOT = path.join(__dirname, "../../..");

/**
 * Ceiling on a client-supplied voice transcript.
 */
const MAX_LIVE_TRANSCRIPT_CHARS = 20000;

/**
 * How many analyses one client may have running at once.
 */
const MAX_CONCURRENT_SESSIONS_PER_CLIENT = 3;

/**
 * Grace period on top of the pipeline's own budget before a "processing"
 * session is considered abandoned.
 */
const STALE_GRACE_MS = 60 * 1000;

class AiSmartCaseController {
  /**
   * POST /api/ai/smart-case/analyze
   */
  async analyzeSmartCase(req, res, next) {
    let documentFiles = [];
    let voiceFile = null;

    try {
      const clientId = req.user?._id;
      if (!clientId) {
        return ApiResponse.error(res, "You must be signed in to use the AI assistant.", 401);
      }

      documentFiles =
        req.files?.documents || (Array.isArray(req.files) ? req.files : []);
      voiceFile = req.files?.voice ? req.files.voice[0] : req.file || null;

      // ── Idempotency ──────────────────────────────────────────────────────
      // Accepted from either the header or a form field. Browsers cannot send
      // `X-Request-Id` unless the CORS preflight allows it by name, and the
      // reverse proxy in front of this app answers OPTIONS itself with a fixed
      // allow-list that does not include it — so web clients send the key as a
      // multipart field. Native clients still send the header.
      //
      // Without the fallback, a web upload would arrive with no key at all and
      // every retry would start a *new* analysis instead of rejoining the one
      // already running.
      const requestId = String(
        req.get("X-Request-Id") || req.body?.requestId || ""
      )
        .trim()
        .slice(0, 128);

      if (requestId) {
        const existing = await AiSmartCaseSession.findOne({
          client: clientId,
          requestId,
        });

        if (existing) {
          log.info("analyze:idempotent-replay", {
            session: existing._id,
            requestId,
          });
          await removeUploadedFiles([...documentFiles, voiceFile]);

          return ApiResponse.success(res, "Analysis already started.", {
            sessionId: existing._id.toString(),
            status: existing.status,
            progress: existing.progress,
            uploadedDocuments: existing.uploadedDocuments,
            documentCount: existing.uploadedDocuments.length,
          }, 202);
        }
      }

      if (!documentFiles || documentFiles.length === 0) {
        await removeUploadedFiles([voiceFile]);
        return ApiResponse.error(
          res,
          "Please upload at least one supporting document to use the AI Smart Assistant. A voice note or written notes can add extra detail, but a document is required.",
          422
        );
      }

      // ── Concurrency ──────────────────────────────────────────────────────
      await failStaleSessions({ client: clientId });

      const running = await AiSmartCaseSession.countDocuments({
        client: clientId,
        status: "processing",
      });

      if (running >= MAX_CONCURRENT_SESSIONS_PER_CLIENT) {
        await removeUploadedFiles([...documentFiles, voiceFile]);
        log.warn("analyze:rejected-concurrency", { client: clientId, running });
        return ApiResponse.error(
          res,
          "You already have analyses running. Please wait for them to finish before starting another.",
          429
        );
      }

      const typedDescription = ((req.body && req.body.issueDescription) || "")
        .toString()
        .trim()
        .slice(0, 5000);

      const liveVoiceTranscript = ((req.body && req.body.voiceTranscript) || "")
        .toString()
        .trim()
        .slice(0, MAX_LIVE_TRANSCRIPT_CHARS);

      const uploadedDocsForDb = [];
      for (const file of documentFiles) {
        const url = "/" + path.relative(PROJECT_ROOT, file.path).replace(/\\/g, "/");

        let documentId = null;
        try {
          const record = await Document.create({
            clientId,
            originalName: file.originalname,
            fileName: path.basename(file.path),
            filePath: url,
            mimeType: file.mimetype,
            fileSize: file.size,
          });
          documentId = record._id;
        } catch (e) {
          log.error("analyze:document-record-failed", e, { name: file.originalname });
        }

        uploadedDocsForDb.push({
          documentId,
          originalName: file.originalname,
          mimeType: file.mimetype,
          size: file.size,
          path: file.path,
          url,
          documentType: file.mimetype,
          ocrQuality: "Pending",
        });
      }

      let session;
      try {
        session = await AiSmartCaseSession.create({
          client: clientId,
          requestId: requestId || undefined,
          status: "processing",
          uploadedDocuments: uploadedDocsForDb,
          voiceTranscript: liveVoiceTranscript,
          voiceTranscriptSource: liveVoiceTranscript ? "live" : "none",
          progress: {
            stage: "queued",
            message: "Preparing your documents",
            percent: 0,
            current: null,
            total: documentFiles.length,
            updatedAt: new Date(),
          },
        });
      } catch (e) {
        if (e.code === 11000 && requestId) {
          const winner = await AiSmartCaseSession.findOne({ client: clientId, requestId });
          if (winner) {
            await removeUploadedFiles([...documentFiles, voiceFile]);
            return ApiResponse.success(res, "Analysis already started.", {
              sessionId: winner._id.toString(),
              status: winner.status,
              progress: winner.progress,
              uploadedDocuments: winner.uploadedDocuments,
              documentCount: winner.uploadedDocuments.length,
            }, 202);
          }
        }
        throw e;
      }

      const payload = {
        sessionId: session._id.toString(),
        status: session.status,
        progress: session.progress,
        uploadedDocuments: session.uploadedDocuments,
        documentCount: documentFiles.length,
      };

      log.info("analyze:accepted", {
        session: session._id,
        client: clientId,
        documents: documentFiles.length,
        voice: Boolean(voiceFile),
      });

      ApiResponse.success(res, "Analysis started.", payload, 202);

      const pipeline = new AiSmartCasePipeline(req.app.get("io"));
      setImmediate(() => {
        pipeline
          .run({ session, documentFiles, voiceFile, typedDescription, liveVoiceTranscript })
          .catch((err) => log.error("analyze:detached-pipeline-rejected", err, {
            session: session._id,
          }));
      });

      return undefined;
    } catch (error) {
      log.error("analyze:failed", error);
      await removeUploadedFiles([...documentFiles, voiceFile]);
      if (res.headersSent) return undefined;
      return next(error);
    }
  }

  /**
   * GET /api/ai/smart-case/history
   */
  async getSmartCaseHistory(req, res, next) {
    try {
      const limit = Math.min(Number(req.query.limit) || 20, 50);

      const sessions = await AiSmartCaseSession.find({ client: req.user._id })
        .sort({ updatedAt: -1 })
        .limit(limit)
        .select("-ocrExtractedText")
        .populate("createdCase", "title status createdAt")
        .lean();

      return ApiResponse.success(res, "AI Smart Case sessions retrieved successfully.", {
        sessions,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/ai/smart-case/session/:id
   */
  async getSmartCaseSessionById(req, res, next) {
    try {
      if (!mongoose.isValidObjectId(req.params.id)) {
        return ApiResponse.error(res, "Session not found.", 404);
      }

      let session = await AiSmartCaseSession.findOne({
        _id: req.params.id,
        client: req.user._id,
      }).populate("createdCase");

      if (!session) {
        return ApiResponse.error(res, "Session not found.", 404);
      }

      if (isStale(session)) {
        log.warn("session:reaping-stale", { session: session._id });
        session = await markAbandoned(session._id);
      }

      return ApiResponse.success(res, "Session retrieved successfully.", {
        session,
        sessionId: session._id.toString(),
        status: session.status,
        progress: session.progress,
        extracted: session.extractedData,
        uploadedDocuments: session.uploadedDocuments,
        voiceTranscript: session.voiceTranscript,
        voiceTranscriptSource: session.voiceTranscriptSource,
        voiceTranscriptionFailed: session.voiceTranscriptionFailed,
        extractionWarnings: session.warnings,
        failureReason: session.failureReason,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/ai/smart-case/session/:id/link-case
   */
  async linkSessionToCase(req, res, next) {
    try {
      const { caseId } = req.body || {};

      if (!caseId || !mongoose.isValidObjectId(caseId)) {
        return ApiResponse.error(res, "A valid caseId is required.", 400);
      }
      if (!mongoose.isValidObjectId(req.params.id)) {
        return ApiResponse.error(res, "Session not found.", 404);
      }

      const session = await AiSmartCaseSession.findOneAndUpdate(
        { _id: req.params.id, client: req.user._id },
        { $set: { createdCase: caseId } },
        { new: true }
      );

      if (!session) {
        return ApiResponse.error(res, "Session not found.", 404);
      }

      return ApiResponse.success(res, "Session linked to case.", { session });
    } catch (error) {
      next(error);
    }
  }
}

function isStale(session) {
  if (session.status !== "processing") return false;
  const last = session.progress?.updatedAt || session.updatedAt || session.createdAt;
  if (!last) return false;
  return Date.now() - new Date(last).getTime() > PIPELINE_BUDGET_MS + STALE_GRACE_MS;
}

const ABANDONED_REASON =
  "The analysis was interrupted and could not be completed. Please try again.";

function abandonedPatch() {
  return {
    $set: {
      status: "failed",
      failureReason: ABANDONED_REASON,
      progress: {
        stage: "failed",
        message: ABANDONED_REASON,
        percent: 100,
        current: null,
        total: null,
        updatedAt: new Date(),
      },
    },
  };
}

async function markAbandoned(sessionId) {
  return AiSmartCaseSession.findByIdAndUpdate(sessionId, abandonedPatch(), { new: true });
}

async function failStaleSessions(filter = {}) {
  const cutoff = new Date(Date.now() - (PIPELINE_BUDGET_MS + STALE_GRACE_MS));

  try {
    const result = await AiSmartCaseSession.updateMany(
      {
        ...filter,
        status: "processing",
        $or: [
          { "progress.updatedAt": { $lt: cutoff } },
          { "progress.updatedAt": { $exists: false }, updatedAt: { $lt: cutoff } },
        ],
      },
      abandonedPatch()
    );

    if (result.modifiedCount > 0) {
      log.warn("recovery:failed-stale-sessions", { count: result.modifiedCount });
    }
    return result.modifiedCount;
  } catch (e) {
    log.error("recovery:sweep-failed", e);
    return 0;
  }
}

async function recoverAbandonedSessions() {
  try {
    const result = await AiSmartCaseSession.updateMany(
      { status: "processing" },
      abandonedPatch()
    );
    if (result.modifiedCount > 0) {
      log.warn("recovery:boot-sweep", { count: result.modifiedCount });
    }
    return result.modifiedCount;
  } catch (e) {
    log.error("recovery:boot-sweep-failed", e);
    return 0;
  }
}

async function removeUploadedFiles(files) {
  await Promise.all(
    (files || [])
      .filter((f) => f && f.path)
      .map((f) =>
        fs.promises
          .unlink(f.path)
          .catch((e) => log.warn("cleanup:unlink-failed", { path: f.path, error: e.message }))
      )
  );
}

module.exports = new AiSmartCaseController();
module.exports.recoverAbandonedSessions = recoverAbandonedSessions;
module.exports.failStaleSessions = failStaleSessions;
