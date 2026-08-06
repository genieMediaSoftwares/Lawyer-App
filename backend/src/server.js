require("dotenv").config();

const http = require("http");
const { Server } = require("socket.io");
const app = require("./app");
const connectDB = require("./config/db");
const { assertEnvironment } = require("./config/env");

// Before anything opens a socket or a database handle: a misconfigured
// deployment should say so once, here, rather than failing one request at a
// time in production.
try {
  const { warnings } = assertEnvironment();
  warnings.forEach((warning) => console.warn(`⚠️  ${warning}`));
} catch (error) {
  console.error(`\n❌ Cannot start: ${error.message}\n`);
  process.exit(1);
}

const PORT = process.env.PORT || 5000;

// Connect MongoDB
connectDB();

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

/**
 * Last-resort process handlers.
 *
 * Node terminates on an unhandled rejection by default and prints nothing
 * useful about where it came from. Logging first, then exiting non-zero, gives
 * the EC2 process manager (systemd or pm2) a clean signal to restart and leaves
 * a diagnosable line in the journal instead of a silent death.
 */
function shutDownOnFatal(label) {
  return (error) => {
    console.error(`\n💥 ${label}:`, error);
    server.close(() => process.exit(1));
    // Do not wait indefinitely for in-flight connections to drain.
    setTimeout(() => process.exit(1), 10000).unref();
  };
}

process.on("unhandledRejection", shutDownOnFatal("Unhandled promise rejection"));
process.on("uncaughtException", shutDownOnFatal("Uncaught exception"));

// Container and systemd stop signals: finish in-flight requests, then exit 0.
["SIGTERM", "SIGINT"].forEach((signal) => {
  process.on(signal, () => {
    console.log(`\n${signal} received — shutting down.`);
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(0), 10000).unref();
  });
});