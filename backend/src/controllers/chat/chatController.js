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
      }).populate("participants", "fullName email mobile profileImage role isVerified");

      if (!chat) {
        chat = await Chat.create({
          participants: [currentUserId, otherUserId],
          lastMessage: "",
          lastMessageAt: new Date()
        });
        chat = await Chat.findById(chat._id).populate("participants", "fullName email mobile profileImage role isVerified");
      }

      let chatObj = chat.toObject();
      const Lawyer = require("../../models/Lawyer");
      for (const p of chatObj.participants || []) {
        if (p.role === "lawyer") {
          const lawyerProfile = await Lawyer.findOne({ user: p._id });
          p.specialization = lawyerProfile ? lawyerProfile.specialization : "";
        } else {
          p.specialization = "";
        }
      }
      const Case = require("../../models/Case");
      const linkedCase = await Case.findOne({
        $or: [
          { assignedLawyer: currentUserId, client: otherUserId },
          { selectedLawyer: currentUserId, client: otherUserId },
          { assignedLawyer: otherUserId, client: currentUserId },
          { selectedLawyer: otherUserId, client: currentUserId }
        ]
      }).select("title _id");

      if (linkedCase) {
        chatObj.caseInfo = {
          id: linkedCase._id,
          title: linkedCase.title
        };
      }

      const lastMsgDoc = await Message.findOne({ chat: chat._id }).sort({ createdAt: -1 });
      chatObj.isLastMessageRead = lastMsgDoc ? lastMsgDoc.isRead : false;

      return ApiResponse.success(res, "Chat conversation retrieved.", chatObj);
    } catch (error) {
      next(error);
    }
  }

  async getChats(req, res, next) {
    try {
      const currentUserId = req.user._id;
      const Case = require("../../models/Case");

      // Ensure a chat conversation exists for every case assigned to this lawyer
      const assignedCases = await Case.find({ assignedLawyer: currentUserId });
      for (const caseItem of assignedCases) {
        if (caseItem.client) {
          let chat = await Chat.findOne({
            participants: { $all: [currentUserId, caseItem.client] }
          });
          if (!chat) {
            await Chat.create({
              participants: [currentUserId, caseItem.client],
              lastMessage: "Consultation accepted. You can now start messaging.",
              lastMessageAt: new Date()
            });
          }
        }
      }

      const chats = await Chat.find({ participants: currentUserId })
        .populate("participants", "fullName email mobile profileImage role isVerified")
        .sort({ lastMessageAt: -1 })
        .lean();

      const Lawyer = require("../../models/Lawyer");
      for (const chat of chats) {
        for (const p of chat.participants || []) {
          if (p.role === "lawyer") {
            const lawyerProfile = await Lawyer.findOne({ user: p._id });
            p.specialization = lawyerProfile ? lawyerProfile.specialization : "";
          } else {
            p.specialization = "";
          }
        }
      }


      if (chats.length === 0) {
        return ApiResponse.success(res, "Chats fetched successfully.", []);
      }

      const chatIds = chats.map(c => c._id);

      // ── Batch 1: unread counts via aggregation (1 DB query instead of N) ──
      const unreadAgg = await Message.aggregate([
        {
          $match: {
            chat: { $in: chatIds },
            sender: { $ne: currentUserId },
            isRead: false
          }
        },
        {
          $group: { _id: "$chat", count: { $sum: 1 } }
        }
      ]);
      const unreadMap = {};
      unreadAgg.forEach(u => { unreadMap[u._id.toString()] = u.count; });

      // ── Batch 2: find linked cases (1 DB query instead of N) ──
      const otherIds = [];
      const chatToOtherMap = {}; // chatId → otherId

      chats.forEach(chat => {
        const other = (chat.participants || []).find(
          p => p._id.toString() !== currentUserId.toString()
        );
        if (other) {
          otherIds.push(other._id);
          chatToOtherMap[chat._id.toString()] = other._id.toString();
        }
      });

      let caseByOtherId = {};
      if (otherIds.length > 0) {
        const linkedCases = await Case.find({
          $or: [
            { assignedLawyer: currentUserId, client: { $in: otherIds } },
            { selectedLawyer: currentUserId, client: { $in: otherIds } },
            { assignedLawyer: { $in: otherIds }, client: currentUserId },
            { selectedLawyer: { $in: otherIds }, client: currentUserId }
          ]
        }).select("title _id assignedLawyer selectedLawyer client").lean();

        linkedCases.forEach(c => {
          const lawyerId = c.assignedLawyer?.toString() || c.selectedLawyer?.toString() || "";
          const clientId = c.client?.toString() || "";
          const isCurrentUserLawyer = lawyerId === currentUserId.toString();
          // "other" relative to currentUser
          const otherId = isCurrentUserLawyer ? clientId : lawyerId;
          if (otherId && !caseByOtherId[otherId]) {
            caseByOtherId[otherId] = { id: c._id, title: c.title };
          }
        });
      }

      // ── Assemble response ──
      const chatsWithData = await Promise.all(chats.map(async chat => {
        const unreadCount = unreadMap[chat._id.toString()] || 0;
        const otherId = chatToOtherMap[chat._id.toString()];
        const caseInfo = otherId ? (caseByOtherId[otherId] || null) : null;
        const lastMsgDoc = await Message.findOne({ chat: chat._id }).sort({ createdAt: -1 });
        const isLastMessageRead = lastMsgDoc ? lastMsgDoc.isRead : false;
        return { ...chat, unreadCount, caseInfo, isLastMessageRead };
      }));

      return ApiResponse.success(res, "Chats fetched successfully.", chatsWithData);
    } catch (error) {
      next(error);
    }
  }

  async sendMessage(req, res, next) {
    try {
      const { chatId } = req.params;
      const { content, attachments } = req.body;
      const sender = req.user._id;

      if (!content && (!attachments || attachments.length === 0)) {
        return ApiResponse.error(res, "Message content or attachments is required.", 400);
      }

      const message = await Message.create({
        chat: chatId,
        sender,
        content: content || "",
        attachments: attachments || []
      });

      const chat = await Chat.findById(chatId);
      if (chat) {
        chat.lastMessage = content || (attachments && attachments.length > 0 ? "Sent an attachment" : "");
        chat.lastMessageAt = new Date();
        chat.lastMessageSender = sender;
        await chat.save();

        const io = req.app.get("io");
        if (io) {
          const populatedMessage = await Message.findById(message._id)
            .populate("sender", "fullName profileImage role");

          // ── Emit full message to the chatId room ──
          // ChatMessagesNotifier listens here to add message bubbles
          io.of("/chat").to(chatId.toString()).emit("message", populatedMessage);

          // ── Emit lightweight chat_updated to each participant's user room ──
          // ChatsNotifier listens here to update last-message preview + unread badge
          chat.participants.forEach((p) => {
            io.of("/chat").to(p.toString()).emit("chat_updated", {
              chatId: chatId.toString(),
              lastMessage: chat.lastMessage,
              lastMessageAt: chat.lastMessageAt,
              senderId: sender.toString()
            });
          });
        }

        const otherParticipant = chat.participants.find((p) => p.toString() !== sender.toString());
        if (otherParticipant) {
          const textPreview = content || (attachments && attachments.length > 0 ? "Attachment" : "");
          await notificationService.createAndSendNotification({
            senderId: sender,
            receiverId: otherParticipant,
            type: "chat_message",
            title: "New Message",
            message: `${req.user.fullName || "Someone"} sent you a message: "${textPreview.substring(0, 30)}${textPreview.length > 30 ? "..." : ""}"`,
            referenceId: chatId,
          });
        }
      }

      const populatedMsg = await Message.findById(message._id)
        .populate("sender", "fullName profileImage role");

      return ApiResponse.success(res, "Message sent successfully.", populatedMsg, 201);
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

  async uploadAttachment(req, res, next) {
    try {
      if (!req.file) {
        return ApiResponse.error(res, "No file uploaded.", 400);
      }
      const storageService = require("../../services/storageService");
      const metadata = await storageService.uploadFile(req.file, "chat_attachments");
      return ApiResponse.success(res, "File uploaded successfully.", {
        name: req.file.originalname,
        url: metadata.url,
        mimeType: metadata.mimeType || req.file.mimetype,
        size: req.file.size
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new ChatController();
