const Chat = require("../models/Chat");
const socketAuth = require("./socketAuth");

/**
 * Chat namespace.
 *
 * Rooms, and who addresses them:
 *
 *   `<userId>`  — the user's personal room, joined on connect. Conversation
 *                 list events (`chat_updated`, `chat_created`, `chat_read`)
 *                 go here so they reach the user on every device regardless
 *                 of which conversation, if any, is open.
 *   `<chatId>`  — one room per conversation, joined while that conversation is
 *                 on screen. Message bubbles and typing indicators go here.
 *
 * Message fan-out itself lives in chatController.sendMessage, which has the
 * populated sender document. A socket-level "message" handler would emit a
 * second, unpopulated copy of every message, so there deliberately isn't one.
 */
module.exports = (io) => {
  const chatNamespace = io.of("/chat");

  // Reject unauthenticated connections at the handshake.
  chatNamespace.use(socketAuth);

  chatNamespace.on("connection", (socket) => {
    const userId = socket.userId;
    console.log(`🔌 Chat socket connected: ${socket.id} (user ${userId})`);

    socket.join(userId);

    // ── Join the room for one conversation ──
    // Acknowledged so the client can tell a genuine join from a silent denial
    // and stop treating the conversation as live when it isn't.
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
        // A malformed chatId makes Chat.exists throw a CastError. Left
        // unhandled it becomes an unhandled rejection and takes down the
        // process, so a bad id from any client could kill chat for everyone.
        console.warn(`⛔ join failed for chat ${chatId}: ${error.message}`);
        if (typeof ack === "function") ack({ ok: false, reason: "invalid" });
      }
    });

    // ── Leave a conversation room (the screen was closed) ──
    socket.on("leave", ({ chatId } = {}) => {
      if (chatId) socket.leave(chatId.toString());
    });

    // ── Typing indicator — relayed to the conversation room only ──
    // chatId travels with the event: one socket carries every conversation,
    // so without it the receiver cannot tell which thread is being typed in
    // and shows "typing…" on all of them.
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
