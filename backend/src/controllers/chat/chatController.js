const Chat = require("../../models/Chat");
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

      return ApiResponse.success(res, "Chats fetched successfully.", chats);
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

      await Chat.findByIdAndUpdate(chatId, {
        lastMessage: content,
        lastMessageAt: new Date()
      });

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
}

module.exports = new ChatController();
