const mongoose = require("mongoose");

const notificationSchema = new mongoose.Schema(
  {
    notificationId: {
      type: String,
      required: true,
      unique: true,
      default: () => new mongoose.Types.ObjectId().toString(),
      index: true,
    },
    senderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },
    receiverId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    title: {
      type: String,
      required: true,
    },
    message: {
      type: String,
      required: true,
    },
    type: {
      type: String,
      required: true,
      enum: [
        "case_posted",
        "proposal_received",
        "proposal_accepted",
        "proposal_rejected",
        "appointment_requested",
        "appointment_confirmed",
        "appointment_cancelled",
        "chat_message",
        "payment_success",
        "payment_failure",
        "case_status_updated",
        "document_uploaded",
        "profile_verification",
        "review_received",
        "admin_announcement",
        "reminder",
        "general",
      ],
      default: "general",
    },
    priority: {
      type: String,
      enum: ["low", "medium", "high"],
      default: "low",
    },
    metadata: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
    referenceId: {
      type: String,
      default: null,
    },
    isRead: {
      type: Boolean,
      default: false,
      index: true,
    },
    softDelete: {
      type: Boolean,
      default: false,
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

// Optimize query performance with compound index
notificationSchema.index({ receiverId: 1, softDelete: 1, createdAt: -1 });

module.exports = mongoose.model("Notification", notificationSchema);
