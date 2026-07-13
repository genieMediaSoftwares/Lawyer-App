const Notification = require("../../models/Notification");

class NotificationService {
  constructor() {
    this.io = null;
  }

  init(io) {
    this.io = io;
  }

  async createAndSendNotification({
    senderId = null,
    receiverId,
    title,
    message,
    type,
    priority = "low",
    metadata = {},
    referenceId = null,
  }) {
    try {
      if (!receiverId) {
        throw new Error("receiverId is required to create a notification.");
      }

      // Create record in MongoDB
      const notification = await Notification.create({
        senderId,
        receiverId,
        title,
        message,
        type,
        priority,
        metadata,
        referenceId,
        isRead: false,
        softDelete: false,
      });

      // Emit real-time message via socket if initialized
      if (this.io) {
        console.log(`📡 Emitting real-time notification to user room: ${receiverId}`);
        this.io.of("/notifications").to(receiverId.toString()).emit("new_notification", notification);
      } else {
        console.log("⚠️ Socket.io instance not initialized in NotificationService.");
      }

      return notification;
    } catch (error) {
      console.error("❌ Error in NotificationService.createAndSendNotification:", error);
      throw error;
    }
  }
}

module.exports = new NotificationService();
