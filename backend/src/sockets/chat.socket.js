const activeUsers = new Set(); // Keep track of online userIds

module.exports = (io) => {
  const chatNamespace = io.of("/chat");

  chatNamespace.on("connection", (socket) => {
    console.log(`🔌 Chat Socket connected: ${socket.id}`);
    let registeredUserId = null;

    // Join room for specific chat
    socket.on("join", ({ chatId }) => {
      if (chatId) {
        socket.join(chatId.toString());
        console.log(`👥 Socket ${socket.id} joined room: ${chatId}`);
      }
    });

    // Join personal user room to receive chat updates
    socket.on("register", ({ userId }) => {
      if (userId) {
        registeredUserId = userId.toString();
        activeUsers.add(registeredUserId);
        socket.join(registeredUserId);
        console.log(`👤 User joined chat room: ${registeredUserId}`);

        // Broadcast that this user is online
        chatNamespace.emit("user_status", { userId: registeredUserId, status: "online" });
      }
    });

    // Handle check_status request from client
    socket.on("check_status", ({ userId }, callback) => {
      if (userId && callback) {
        const isOnline = activeUsers.has(userId.toString());
        callback({ status: isOnline ? "online" : "offline" });
      }
    });

    // Handle new message event
    socket.on("message", (messageData) => {
      const { chat, sender, content, attachments, createdAt } = messageData;
      console.log(`💬 Message in ${chat} from ${sender}`);
      
      // Broadcast to everyone in the room
      chatNamespace.to(chat).emit("message", {
        chat,
        sender,
        content,
        attachments,
        createdAt: createdAt || new Date(),
      });
    });

    // Handle typing indicator
    socket.on("typing", ({ chatId, userName, isTyping }) => {
      socket.to(chatId).emit("typing", { userName, isTyping });
    });

    socket.on("disconnect", () => {
      if (registeredUserId) {
        activeUsers.delete(registeredUserId);
        // Broadcast that this user is offline
        chatNamespace.emit("user_status", { userId: registeredUserId, status: "offline" });
      }
      console.log(`🔌 Chat Socket disconnected: ${socket.id}`);
    });
  });
};
