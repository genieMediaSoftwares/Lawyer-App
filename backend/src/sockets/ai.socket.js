const socketAuth = require("./socketAuth");

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
 */
module.exports = (io) => {
  const aiNamespace = io.of("/ai");

  aiNamespace.use(socketAuth);

  aiNamespace.on("connection", (socket) => {
    const userId = socket.userId;
    socket.join(userId);
    console.log(`🤖 AI Socket connected: ${socket.id} (user ${userId})`);

    socket.on("disconnect", () => {
      console.log(`🤖 AI Socket disconnected: ${socket.id}`);
    });
  });
};
