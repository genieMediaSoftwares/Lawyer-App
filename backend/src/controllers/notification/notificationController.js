const Notification = require("../../models/Notification");
const ApiResponse = require("../../config/ApiResponse");

class NotificationController {
  async getNotifications(req, res, next) {
    try {
      const recipient = req.user._id;
      const notifications = await Notification.find({ recipient })
        .sort({ createdAt: -1 });

      return ApiResponse.success(res, "Notifications fetched successfully.", notifications);
    } catch (error) {
      next(error);
    }
  }

  async markAsRead(req, res, next) {
    try {
      const { id } = req.params;
      const notification = await Notification.findByIdAndUpdate(
        id,
        { read: true },
        { new: true }
      );

      if (!notification) {
        return ApiResponse.error(res, "Notification not found.", 404);
      }

      return ApiResponse.success(res, "Notification marked as read.", notification);
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new NotificationController();
