const mongoose = require("mongoose");

const issueSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: true,
      trim: true,
    },
    description: {
      type: String,
      required: true,
    },
    category: {
      type: String,
      required: true,
    },
    documents: [
      {
        name: String,
        url: String,
        size: String,
        path: String,
      },
    ],
    images: [
      {
        name: String,
        url: String,
        size: String,
        path: String,
      },
    ],
    clientId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    status: {
      type: String,
      enum: ["Pending", "Assigned", "Resolved", "Closed"],
      default: "Pending",
    },
    urgency: {
      type: String,
      default: "Flexible",
    },
    preferredLanguage: {
      type: String,
      default: "English",
    },
    location: {
      type: String,
      default: "",
    },
    preferredMode: {
      type: String,
      enum: ["Video", "Chat", "Phone"],
      default: "Video",
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model("Issue", issueSchema);
