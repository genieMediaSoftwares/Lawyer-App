const mongoose = require("mongoose");

const messageSchema = new mongoose.Schema(
  {
    chat: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Chat",
      required: true,
    },

    sender: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    content: {
      type: String,
      default: "",
    },

    attachments: [
      {
        name: { type: String, required: true },
        url: { type: String, required: true },
        mimeType: { type: String },
        size: { type: Number }
      }
    ],

    /// Sender-generated id, echoed back on the REST response and on the socket
    /// broadcast. It lets the sender match an incoming message to the bubble it
    /// already drew optimistically, so a message never renders twice no matter
    /// which of the two arrives first.
    clientId: {
      type: String,
      default: "",
    },

    /// Whether the *recipient* has opened the conversation since this arrived.
    /// This is unread-count bookkeeping, not a read receipt: it is never
    /// reported back to the sender.
    isRead: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

// History load: find by chat, sorted oldest-first.
messageSchema.index({ chat: 1, createdAt: 1 });

// Unread-count aggregation: unread messages in a chat not sent by the reader.
messageSchema.index({ chat: 1, isRead: 1, sender: 1 });

module.exports = mongoose.model("Message", messageSchema);
