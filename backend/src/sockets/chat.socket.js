const Chat = require("../models/Chat");
const socketAuth = require("./socketAuth");

module.exports = (io) => {
  const chatNamespace = io.of("/chat");

  chatNamespace.use(socketAuth);

  chatNamespace.on("connection", (socket) => {
    const userId = socket.userId;
    console.log(`🔌 Chat socket connected: ${socket.id} (user ${userId})`);

    socket.join(userId);

    socket.on("join", async ({ chatId } = {}, ack) => {
      if (!chatId) {
        if (typeof ack === "function") ack({ ok: false, reason: "no_chat_id" });
        return;
      }

      try {
        const isParticipant = await Chat.exists({
          _id: chatId,
          participants: userId,
        });

        if (!isParticipant) {
          console.warn(
            `⛔ User ${userId} denied join on chat ${chatId} (not a participant)`
          );
          if (typeof ack === "function") ack({ ok: false, reason: "forbidden" });
          return socket.emit("error", {
            message: "Not a participant of this chat.",
          });
        }

        socket.join(chatId.toString());
        if (typeof ack === "function") ack({ ok: true });
      } catch (error) {
        console.warn(`⛔ join failed for chat ${chatId}: ${error.message}`);
        if (typeof ack === "function") ack({ ok: false, reason: "invalid" });
      }
    });

    socket.on("leave", ({ chatId } = {}) => {
      if (chatId) socket.leave(chatId.toString());
    });

    socket.on("typing", ({ chatId, userName, isTyping } = {}) => {
      if (!chatId) return;
      socket.to(chatId.toString()).emit("typing", {
        chatId: chatId.toString(),
        userName,
        isTyping: isTyping === true,
      });
    });

    socket.on("disconnect", (reason) => {
      console.log(`🔌 Chat socket disconnected: ${socket.id} (${reason})`);
    });
  });
};
