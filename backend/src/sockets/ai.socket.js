const socketAuth = require("./socketAuth");
const mongoose = require("mongoose");
const AiSmartCaseSession = require("../models/AiSmartCaseSession");
const log = require("../utils/aiLogger");

/**
 * Real-time channel for the AI Smart Case Assistant pipeline.
 *
 * The analyze endpoint returns as soon as the upload has landed; every stage
 * after that (OCR per document, transcription, extraction, classification)
 * reports here. Nothing about the progress a client sees is generated on the
 * device — see `aiSmartCasePipeline.emit`.
 *
 * Rooms are the authenticated user id, joined from the verified handshake in
 * the same way as /cases and /notifications. A client-supplied session id is
 * never trusted to name a room, so one client cannot watch another's intake.
 *
 * The socket is an accelerator, never the source of truth: everything it
 * carries is also readable from `GET /ai/smart-case/session/:id`, which is
 * what the client polls when this connection is down. Nothing here may be the
 * only way to learn something.
 */
module.exports = (io) => {
  const aiNamespace = io.of("/ai");

  aiNamespace.use(socketAuth);

  aiNamespace.on("connection", (socket) => {
    const userId = socket.userId;
    socket.join(userId);
    log.info("socket:connected", { socket: socket.id, user: userId });

    /**
     * Explicit resync for a client that has just reconnected.
     *
     * Events emitted while a socket was down are not queued anywhere — they are
     * simply gone — so a reconnecting client has to ask for current state. It
     * can do that over HTTP, and does, but a round trip through the same socket
     * it just re-established is faster and works even when the poll is what is
     * struggling.
     *
     * Ownership is checked against the *verified* handshake id, never against
     * anything in the payload, so this cannot be used to read another client's
     * intake.
     */
    socket.on("watch_session", async (payload, ack) => {
      const respond = typeof ack === "function" ? ack : () => {};

      try {
        const sessionId = String(payload?.sessionId || "");
        if (!mongoose.isValidObjectId(sessionId)) {
          return respond({ error: "Invalid session id." });
        }

        const session = await AiSmartCaseSession.findOne({
          _id: sessionId,
          client: userId,
        }).lean();

        if (!session) {
          return respond({ error: "Session not found." });
        }

        // Same flattened shape as `analysis_complete` and the REST session
        // response, so the client parses all three with one model.
        return respond({
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
      } catch (e) {
        log.error("socket:watch-session-failed", e, { user: userId });
        return respond({ error: "Could not read that session." });
      }
    });

    // Without this an exception inside a handler surfaces as an unhandled
    // 'error' event, which in Node terminates the process — one malformed
    // payload from one client would take the whole server down.
    socket.on("error", (err) => {
      log.error("socket:error", err, { socket: socket.id, user: userId });
    });

    socket.on("disconnect", (reason) => {
      log.info("socket:disconnected", { socket: socket.id, user: userId, reason });
    });
  });

  aiNamespace.on("connection_error", (err) => {
    log.warn("socket:connection-error", { message: err?.message });
  });
};
