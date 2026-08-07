require("dotenv").config();

const http = require("http");
const { Server } = require("socket.io");
const app = require("./app");
const connectDB = require("./config/db");

const {
  recoverAbandonedSessions,
} = require("./controllers/ai/aiSmartCaseController");

const PORT = process.env.PORT || 5000;

// Connect MongoDB, then reap anything the previous process left mid-flight.
//
// The AI Smart Case pipeline runs in-process and detached from the request that
// started it, so a deploy or a crash during an analysis leaves a session marked
// "processing" that nothing will ever advance. Any client still on the
// processing screen polls it forever, and it counts against that client's
// concurrency cap until someone edits the database. Failing them at boot is
// what makes a restart a recoverable event rather than a stuck session.
connectDB().then(() => {
  recoverAbandonedSessions().catch((e) =>
    console.error("Abandoned AI session sweep failed:", e.message)
  );
});

// Create HTTP Server
const server = http.createServer(app);

// Socket.IO — origins allowlisted in production, matching the REST CORS policy.
// Each namespace additionally installs socketAuth, so an allowed origin still
// has to present a valid JWT at the handshake.
const allowedOrigins = (process.env.ALLOWED_ORIGINS || "")
  .split(",")
  .map((origin) => origin.trim())
  .filter(Boolean);

const io = new Server(server, {
  cors: {
    origin: process.env.NODE_ENV === "production" ? allowedOrigins : "*",
    methods: ["GET", "POST"],
  },
});

// Make io available globally
app.set("io", io);

// Socket Handlers
require("./sockets/chat.socket")(io);
require("./sockets/notification.socket")(io);
require("./sockets/case.socket")(io);
require("./sockets/ai.socket")(io);

// Start Server
server.listen(PORT, "0.0.0.0", () => {
  console.log(`
=========================================
🚀 Server Started Successfully
🌐 URL : ${process.env.BACKEND_URL || `http://localhost:${PORT}`}
📦 Environment : ${process.env.NODE_ENV || "development"}
=========================================
`);
});