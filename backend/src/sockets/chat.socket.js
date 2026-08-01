const Chat = require("../models/Chat");
const socketAuth = require("./socketAuth");

const activeUsers = new Set(); // Keep track of online userIds

module.exports = (io) => {
  const chatNamespace = io.of("/chat");

  // Reject unauthenticated connections at the handshake.
  chatNamespace.use(socketAuth);

  chatNamespace.on("connection", (socket) => {
    const userId = socket.userId;
    console.log(`🔌 Chat Socket connected: ${socket.id} (user ${userId})`);

    socket.join(userId);
    activeUsers.add(userId);
    chatNamespace.emit("user_status", { userId, status: "online" });

    // ── Join room for a specific chat conversation ──
    socket.on("join", async ({ chatId }) => {
      if (!chatId) return;

      const isParticipant = await Chat.exists({
        _id: chatId,
        participants: userId,
      });

      if (!isParticipant) {
        console.warn(
          `⛔ User ${userId} denied join on chat ${chatId} (not a participant)`
        );
        return socket.emit("error", {
          message: "Not a participant of this chat.",
        });
      }

      socket.join(chatId.toString());
      console.log(`👥 Socket ${socket.id} joined chat room: ${chatId}`);
    });

    // ── Status check from a client ──
    socket.on("check_status", ({ userId: targetId }, callback) => {
      if (targetId && callback) {
        callback({
          status: activeUsers.has(targetId.toString()) ? "online" : "offline",
        });
      }
    });

    // ── Typing indicator — relay to the chat room only ──

    socket.on("typing", ({ chatId, userName, isTyping }) => {
      if (chatId) {
        socket.to(chatId.toString()).emit("typing", { userName, isTyping });
      }
    });

    // NOTE: We intentionally do NOT handle a socket-level "message" event here.
    // All message broadcasting is done by the REST controller (chatController.sendMessage)
    // which uses populated sender data. A socket-level handler would cause a
    // duplicate broadcast with unpopulated data.

    socket.on("disconnect", () => {
      activeUsers.delete(userId);
      chatNamespace.emit("user_status", { userId, status: "offline" });
      console.log(`🔌 Chat Socket disconnected: ${socket.id}`);
    });
  });
};
