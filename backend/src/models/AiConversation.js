const mongoose = require("mongoose");

const messageSchema = new mongoose.Schema(
  {
    role: {
      type: String,
      enum: ["user", "model", "assistant"],
      required: true,
    },
    text: {
      type: String,
      required: true,
    },
    timestamp: {
      type: Date,
      default: Date.now,
    },
  },
  { _id: true }
);

const aiConversationSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    title: {
      type: String,
      required: true,
      trim: true,
      default: "New Legal Conversation",
    },
    status: {
      type: String,
      enum: ["active", "archived"],
      default: "active",
    },

    mode: {
      type: String,
      enum: ["chat", "research"],
      default: "chat",
    },
    messages: [messageSchema],
  },
  {
    timestamps: true,
  }
);

aiConversationSchema.index({ userId: 1, updatedAt: -1 });
aiConversationSchema.index({ userId: 1, mode: 1, updatedAt: -1 });

module.exports = mongoose.model("AiConversation", aiConversationSchema);
