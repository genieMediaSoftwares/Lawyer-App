const path = require("path");
const ApiResponse = require("../../config/ApiResponse");
const AiSmartCaseSession = require("../../models/AiSmartCaseSession");
const Document = require("../../models/Document");
const { AiSmartCasePipeline } = require("../../services/ai/aiSmartCasePipeline");

/** Repo root, used to turn an absolute upload path into a served URL. */
const PROJECT_ROOT = path.join(__dirname, "../../..");

class AiSmartCaseController {
  /**
   * POST /api/ai/smart-case/analyze
   *
   * Accepts the documents and optional voice note, persists a "processing"
   * session, and returns its id straight away. The analysis itself runs
   * detached and reports over the /ai Socket.IO namespace.
   *
   * This shape replaced a single blocking request that held the connection for
   * the whole pipeline. That could not work: OCR plus transcription plus
   * extraction routinely outran the client's receive timeout and Node's own
   * request timeout, so the client aborted while the server carried on
   * working, and the finished result had nowhere to go. Returning an id first
   * also means the run survives the client backgrounding or reconnecting.
   */
  async analyzeSmartCase(req, res, next) {
    try {
      const clientId = req.user._id;

      const documentFiles =
        req.files?.documents || (Array.isArray(req.files) ? req.files : []);
      const voiceFile = req.files?.voice ? req.files.voice[0] : req.file || null;

      // The document is the primary input the assistant reasons from; voice
      // and typed notes only ever supplement it.
      if (!documentFiles || documentFiles.length === 0) {
        return ApiResponse.error(
          res,
          "Please upload at least one supporting document to use the AI Smart Assistant. A voice note or written notes can add extra detail, but a document is required.",
          422
        );
      }

      const typedDescription = ((req.body && req.body.issueDescription) || "").trim();

      // Register each upload in the Document collection, the same one the
      // manual Post Case upload writes to. Without this the AI flow produced
      // files that existed on disk but had no record, so the Post Case form
      // could not treat them as attached and asked the client to upload the
      // very files they had just given us.
      const uploadedDocsForDb = [];
      for (const file of documentFiles) {
        const url =
          "/" + path.relative(PROJECT_ROOT, file.path).replace(/\\/g, "/");

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
          // A missing catalogue row must not lose the client's upload; the file
          // is still on disk and still analysed.
          console.error("Could not create Document record for AI upload:", e.message);
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

      const session = await AiSmartCaseSession.create({
        client: clientId,
        status: "processing",
        uploadedDocuments: uploadedDocsForDb,
        voiceTranscript: "",
        progress: {
          stage: "queued",
          message: "Preparing your documents",
          percent: 0,
          current: null,
          total: documentFiles.length,
          updatedAt: new Date(),
        },
      });

      const payload = {
        sessionId: session._id.toString(),
        status: session.status,
        progress: session.progress,
        uploadedDocuments: session.uploadedDocuments,
        documentCount: documentFiles.length,
      };

      // Respond before starting work. `setImmediate` defers the pipeline to the
      // next tick so the response is flushed first and the client is already
      // listening when the first progress event fires.
      ApiResponse.success(res, "Analysis started.", payload, 202);

      const pipeline = new AiSmartCasePipeline(req.app.get("io"));
      setImmediate(() => {
        pipeline
          .run({ session, documentFiles, voiceFile, typedDescription })
          .catch((err) => console.error("Detached pipeline rejected:", err));
      });

      return undefined;
    } catch (error) {
      console.error("Analyze Smart Case Error:", error);
      next(error);
    }
  }

  /**
   * GET /api/ai/smart-case/history
   * Previous intake sessions for the client.
   */
  async getSmartCaseHistory(req, res, next) {
    try {
      const sessions = await AiSmartCaseSession.find({ client: req.user._id })
        .sort({ updatedAt: -1 })
        .populate("createdCase", "title status createdAt");

      return ApiResponse.success(res, "AI Smart Case sessions retrieved successfully.", {
        sessions,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/ai/smart-case/session/:id
   *
   * The reconnect and poll path. A client that missed socket events — it was
   * backgrounded, the connection dropped, the user switched devices — reads the
   * authoritative state here and renders exactly what the events would have
   * produced.
   */
  async getSmartCaseSessionById(req, res, next) {
    try {
      const session = await AiSmartCaseSession.findOne({
        _id: req.params.id,
        client: req.user._id,
      }).populate("createdCase");

      if (!session) {
        return ApiResponse.error(res, "Session not found.", 404);
      }

      return ApiResponse.success(res, "Session retrieved successfully.", {
        session,
        // Flattened alongside the session so the completion payload is
        // identical in shape to the `analysis_complete` socket event, and the
        // client can parse both with one model.
        sessionId: session._id.toString(),
        status: session.status,
        progress: session.progress,
        extracted: session.extractedData,
        uploadedDocuments: session.uploadedDocuments,
        voiceTranscript: session.voiceTranscript,
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
   *
   * Records which case an intake session produced, closing the audit trail
   * from uploaded document through to filed case.
   */
  async linkSessionToCase(req, res, next) {
    try {
      const { caseId } = req.body;
      if (!caseId) {
        return ApiResponse.error(res, "caseId is required.", 400);
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

module.exports = new AiSmartCaseController();
