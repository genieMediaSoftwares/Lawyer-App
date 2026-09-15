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

    /// Which surface owns this conversation.
    ///
    /// "chat" is the client-facing AI legal assistant; "research" is the
    /// advocate-facing research assistant. They share this collection and the
    /// same Gemini client but must not share a history list - a lawyer's
    /// research should not appear in the client chat screen, and vice versa.
    ///
    /// Deliberately NOT required and with no default written to old documents:
    /// conversations created before this field existed have no mode at all,
    /// and the chat listing matches them with { mode: { $ne: "research" } },
    /// which in MongoDB also matches documents where the field is missing. So
    /// every pre-existing conversation keeps showing up exactly where it did.
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

// Index for fast querying by user and last update time
aiConversationSchema.index({ userId: 1, updatedAt: -1 });
aiConversationSchema.index({ userId: 1, mode: 1, updatedAt: -1 });

module.exports = mongoose.model("AiConversation", aiConversationSchema);
