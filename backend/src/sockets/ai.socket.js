const socketAuth = require("./socketAuth");
const mongoose = require("mongoose");
const AiSmartCaseSession = require("../models/AiSmartCaseSession");
const log = require("../utils/aiLogger");

module.exports = (io) => {
  const aiNamespace = io.of("/ai");

  aiNamespace.use(socketAuth);

  aiNamespace.on("connection", (socket) => {
    const userId = socket.userId;
    socket.join(userId);
    log.info("socket:connected", { socket: socket.id, user: userId });

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
