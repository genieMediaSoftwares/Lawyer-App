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

    caseId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Case",
      default: null,
    },
    caseTitle: {
      type: String,
      default: "",
    },
    jurisdiction: {
      type: String,
      default: "",
    },
    researchDocuments: [
      {
        _id: false,
        documentId: { type: String, required: true },
        name: { type: String, default: "" },
        reference: { type: String, default: "" },
        status: {
          type: String,
          enum: ["pending", "used", "truncated", "failed", "unsupported", "missing"],
          required: true,
        },
        charCount: { type: Number, default: 0 },
        note: { type: String, default: "" },
      },
    ],
    documentContext: {
      type: String,
      default: "",
      select: false,
    },
    researchStatus: {
      type: String,
      enum: ["idle", "processing", "completed", "failed"],
      default: "idle",
    },
    researchStage: {
      type: String,
      default: "",
    },
    researchError: {
      type: String,
      default: "",
    },
    relevantCases: {
      status: {
        type: String,
        enum: ["idle", "searching", "completed", "failed", "unavailable"],
        default: "idle",
      },
      query: { type: String, default: "" },
      jurisdiction: { type: String, default: "" },
      provider: { type: String, default: "" },
      searchedAt: { type: Date, default: null },
      message: { type: String, default: "" },
      results: [
        {
          _id: false,
          caseTitle: { type: String, required: true },
          citation: { type: String, default: "" },
          court: { type: String, default: "" },
          jurisdiction: { type: String, default: "" },
          decisionDate: { type: String, default: "" },
          relevanceSummary: { type: String, default: "" },
          legalPrinciple: { type: String, default: "" },
          sources: [
            {
              _id: false,
              url: { type: String, required: true },
              name: { type: String, default: "" },
            },
          ],
          verificationStatus: {
            type: String,
            enum: ["Source Retrieved", "Search Result — Not Yet Verified"],
            required: true,
          },
          retrievedAt: { type: Date, default: Date.now },
        },
      ],
    },
  },
  {
    timestamps: true,
  }
);

aiConversationSchema.index({ userId: 1, updatedAt: -1 });
aiConversationSchema.index({ userId: 1, mode: 1, updatedAt: -1 });
aiConversationSchema.index({ researchStatus: 1 });
aiConversationSchema.index({ "relevantCases.status": 1 });

module.exports = mongoose.model("AiConversation", aiConversationSchema);
