module.exports = (io) => {
  const chatNamespace = io.of("/chat");

  chatNamespace.on("connection", (socket) => {
    console.log(`🔌 Chat Socket connected: ${socket.id}`);

    // Join room for specific chat
    socket.on("join", ({ chatId }) => {
      socket.join(chatId);
      console.log(`👥 Socket ${socket.id} joined room: ${chatId}`);
    });

    // Handle new message event
    socket.on("message", (messageData) => {
      const { chat, sender, content, attachments, createdAt } = messageData;
      console.log(`💬 Message in ${chat} from ${sender}`);
      
      // Broadcast to everyone in the room except sender or including sender
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
      console.log(`🔌 Chat Socket disconnected: ${socket.id}`);
    });
  });
};
