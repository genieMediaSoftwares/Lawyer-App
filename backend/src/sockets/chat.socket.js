const activeUsers = new Set(); // Keep track of online userIds

module.exports = (io) => {
  const chatNamespace = io.of("/chat");

  chatNamespace.on("connection", (socket) => {
    console.log(`🔌 Chat Socket connected: ${socket.id}`);
    let registeredUserId = null;

    // ── Join room for a specific chat conversation ──
    socket.on("join", ({ chatId }) => {
      if (chatId) {
        socket.join(chatId.toString());
        console.log(`👥 Socket ${socket.id} joined chat room: ${chatId}`);
      }
    });

    // ── Join personal user room to receive chat_updated events ──
    socket.on("register", ({ userId }) => {
      if (userId) {
        registeredUserId = userId.toString();
        activeUsers.add(registeredUserId);
        socket.join(registeredUserId);
        console.log(`👤 User registered in chat: ${registeredUserId}`);

        // Broadcast online status to all connected clients
        chatNamespace.emit("user_status", { userId: registeredUserId, status: "online" });
      }
    });

    // ── Status check from a client ──
    socket.on("check_status", ({ userId }, callback) => {
      if (userId && callback) {
        const isOnline = activeUsers.has(userId.toString());
        callback({ status: isOnline ? "online" : "offline" });
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
      if (registeredUserId) {
        activeUsers.delete(registeredUserId);
        // Broadcast offline status
        chatNamespace.emit("user_status", { userId: registeredUserId, status: "offline" });
      }
      console.log(`🔌 Chat Socket disconnected: ${socket.id}`);
    });
  });
};
