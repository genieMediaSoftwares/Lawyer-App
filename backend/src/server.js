require("dotenv").config();

const http = require("http");
const { Server } = require("socket.io");
const app = require("./app");
const connectDB = require("./config/db");

const PORT = process.env.PORT || 5000;

// Connect MongoDB
connectDB();

// Create HTTP Server
const server = http.createServer(app);

// Socket.IO
const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
  },
});

// Make io available globally
app.set("io", io);

// Socket Handlers
require("./sockets/chat.socket")(io);
require("./sockets/notification.socket")(io);
require("./sockets/case.socket")(io);

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