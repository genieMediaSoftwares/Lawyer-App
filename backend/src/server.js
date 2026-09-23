require("dotenv").config();

const http = require("http");
const { Server } = require("socket.io");
const app = require("./app");
const connectDB = require("./config/db");
const { assertEnvironment } = require("./config/env");

try {
  const { warnings } = assertEnvironment();
  warnings.forEach((warning) => console.warn(`⚠️  ${warning}`));
} catch (error) {
  console.error(`\n❌ Cannot start: ${error.message}\n`);
  process.exit(1);
}

const {
  recoverAbandonedSessions,
} = require("./controllers/ai/aiSmartCaseController");

const PORT = process.env.PORT || 5000;

connectDB().then(() => {
  require("./services/ai/legalResearchService").recoverAbandonedResearch().catch((e) =>
    console.error("Abandoned research sweep failed:", e.message)
  );
  recoverAbandonedSessions().catch((e) =>
    console.error("Abandoned AI session sweep failed:", e.message)
  );
});

const server = http.createServer(app);

const DEFAULT_ALLOWED_ORIGINS = ["https://lawappadmin.vercel.app"];
const configuredOrigins = (process.env.ALLOWED_ORIGINS || "")
  .split(",")
  .map((origin) => origin.trim())
  .filter(Boolean);
const allowedOrigins = [
  ...new Set([...DEFAULT_ALLOWED_ORIGINS, ...configuredOrigins.filter((o) => o !== "*")]),
];

const io = new Server(server, {
  cors: {
    origin: process.env.NODE_ENV === "production" ? allowedOrigins : "*",
    methods: ["GET", "POST"],
  },
});

app.set("io", io);

require("./sockets/chat.socket")(io);
require("./sockets/notification.socket")(io);
require("./sockets/case.socket")(io);
require("./sockets/ai.socket")(io);

server.listen(PORT, "0.0.0.0", () => {
  console.log(`
=========================================
🚀 Server Started Successfully
🌐 URL : ${process.env.BACKEND_URL || `http://localhost:${PORT}`}
📦 Environment : ${process.env.NODE_ENV || "development"}
=========================================
`);
});

function shutDownOnFatal(label) {
  return (error) => {
    console.error(`\n💥 ${label}:`, error);
    server.close(() => process.exit(1));
    setTimeout(() => process.exit(1), 10000).unref();
  };
}

process.on("unhandledRejection", shutDownOnFatal("Unhandled promise rejection"));
process.on("uncaughtException", shutDownOnFatal("Uncaught exception"));

["SIGTERM", "SIGINT"].forEach((signal) => {
  process.on(signal, () => {
    console.log(`\n${signal} received — shutting down.`);
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(0), 10000).unref();
  });
});