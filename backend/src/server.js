require("dotenv").config();

const http = require("http");
const { Server } = require("socket.io");
const app = require("./app");
const connectDB = require("./config/db");

const PORT = process.env.PORT || 5000;

// Connect Database
connectDB();

// Create HTTP Server
const server = http.createServer(app);

// Initialize Socket.io
const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Load Socket Handlers
require("./sockets/chat.socket")(io);
require("./sockets/notification.socket")(io);

// Start Server
server.listen(PORT, "0.0.0.0", () => {
  console.log(`
=========================================
🚀 Server Started Successfully (with Socket.io)
🌐 URL : http://localhost:${PORT}
📦 Environment : ${process.env.NODE_ENV}
=========================================
`);
});