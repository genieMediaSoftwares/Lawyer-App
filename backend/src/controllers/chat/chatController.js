const Chat = require("../../models/Chat");
const notificationService = require("../../services/notification/notificationService");
const Message = require("../../models/Message");
const ApiResponse = require("../../config/ApiResponse");

class ChatController {
  async getOrCreateChat(req, res, next) {
    try {
      const { otherUserId } = req.body;
      const currentUserId = req.user._id;

      if (!otherUserId) {
        return ApiResponse.error(res, "otherUserId is required.", 400);
      }

      // Check if conversation already exists
      let chat = await Chat.findOne({
        participants: { $all: [currentUserId, otherUserId] }
      }).populate("participants", "fullName email mobile profileImage role");

      if (!chat) {
        chat = await Chat.create({
          participants: [currentUserId, otherUserId],
          lastMessage: "",
          lastMessageAt: new Date()
        });
        chat = await Chat.findById(chat._id).populate("participants", "fullName email mobile profileImage role");
      }

      return ApiResponse.success(res, "Chat conversation retrieved.", chat);
    } catch (error) {
      next(error);
    }
  }

  async getChats(req, res, next) {
    try {
      const currentUserId = req.user._id;

      const chats = await Chat.find({
        participants: currentUserId
      })
        .populate("participants", "fullName email mobile profileImage role")
        .sort({ lastMessageAt: -1 });

      // Count unread messages for each chat conversation dynamically
      const chatsWithUnread = await Promise.all(
        chats.map(async (chat) => {
          const unreadCount = await Message.countDocuments({
            chat: chat._id,
            sender: { $ne: currentUserId },
            isRead: false
          });
          return {
            ...chat.toObject(),
            unreadCount,
          };
        })
      );

      return ApiResponse.success(res, "Chats fetched successfully.", chatsWithUnread);
    } catch (error) {
      next(error);
    }
  }

  async sendMessage(req, res, next) {
    try {
      const { chatId } = req.params;
      const { content } = req.body;
      const sender = req.user._id;

      if (!content) {
        return ApiResponse.error(res, "Message content is required.", 400);
      }

      const message = await Message.create({
        chat: chatId,
        sender,
        content
      });

      const chat = await Chat.findById(chatId);
      if (chat) {
        chat.lastMessage = content;
        chat.lastMessageAt = new Date();
        await chat.save();

        const io = req.app.get("io");
        if (io) {
          const populatedMessage = await Message.findById(message._id)
            .populate("sender", "fullName profileImage role");

          // Emit to chatId room
          io.of("/chat").to(chatId.toString()).emit("message", populatedMessage);

          // Emit to participants rooms
          chat.participants.forEach((p) => {
            io.of("/chat").to(p.toString()).emit("message", populatedMessage);
          });
        }

        const otherParticipant = chat.participants.find((p) => p.toString() !== sender.toString());
        if (otherParticipant) {
          await notificationService.createAndSendNotification({
            senderId: sender,
            receiverId: otherParticipant,
            type: "chat_message",
            title: "New Message",
            message: `${req.user.fullName || "Someone"} sent you a message: "${content.substring(0, 30)}${content.length > 30 ? '...' : ''}"`,
            referenceId: chatId,
          });
        }
      }

      return ApiResponse.success(res, "Message sent successfully.", message, 201);
    } catch (error) {
      next(error);
    }
  }

  async getMessages(req, res, next) {
    try {
      const { chatId } = req.params;

      const messages = await Message.find({ chat: chatId })
        .populate("sender", "fullName profileImage role")
        .sort({ createdAt: 1 });

      return ApiResponse.success(res, "Messages fetched successfully.", messages);
    } catch (error) {
      next(error);
    }
  }

  async markAsRead(req, res, next) {
    try {
      const { chatId } = req.params;
      const currentUserId = req.user._id;

      await Message.updateMany(
        { chat: chatId, sender: { $ne: currentUserId }, isRead: false },
        { isRead: true }
      );

      const io = req.app.get("io");
      if (io) {
        io.of("/chat").to(chatId.toString()).emit("read", { chatId, readBy: currentUserId });
      }

      return ApiResponse.success(res, "Messages marked as read.");
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new ChatController();
