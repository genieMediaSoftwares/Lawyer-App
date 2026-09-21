const mongoose = require("mongoose");

const aiSmartCaseSessionSchema = new mongoose.Schema(
  {
    client: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    requestId: {
      type: String,
      default: undefined,
    },

    status: {
      type: String,
      enum: ["processing", "extracted", "failed"],
      default: "processing",
    },

    progress: {
      stage: { type: String, default: "queued" },
      message: { type: String, default: "" },
      percent: { type: Number, default: 0 },
      current: { type: Number, default: null },
      total: { type: Number, default: null },
      updatedAt: { type: Date, default: Date.now },
    },

    failureReason: {
      type: String,
      default: "",
    },

    warnings: {
      type: [String],
      default: [],
    },

    voiceTranscriptionFailed: {
      type: Boolean,
      default: false,
    },

    uploadedDocuments: [
      {
        documentId: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "Document",
          default: null,
        },
        originalName: String,
        mimeType: String,
        size: Number,
        path: String,
        url: String,
        documentType: { type: String, default: "Unknown" },
        ocrQuality: { type: String, default: "Good" },
      },
    ],

    ocrExtractedText: {
      type: String,
      default: "",
    },

    voiceTranscript: {
      type: String,
      default: "",
    },

    voiceTranscriptLanguage: {
      type: String,
      enum: ["", "en", "hi", "te"],
      default: "",
    },

    voiceTranscriptSource: {
      type: String,
      enum: ["none", "live", "server"],
      default: "none",
    },

    serverVoiceTranscript: {
      type: String,
      default: "",
    },

    extractedData: {
      title: { type: String, default: "" },
      description: { type: String, default: "" },
      category: { type: String, default: "" },
      categoryId: { type: String, default: "" },
      subType: { type: String, default: "" },
      urgency: { type: String, default: "" },
      city: { type: String, default: "" },
      state: { type: String, default: "" },
      location: { type: String, default: "" },
      court: { type: String, default: "" },
      incidentDate: { type: Date, default: null },
      opposingParty: { type: String, default: "" },
      firNumber: { type: String, default: "" },
      policeStation: { type: String, default: "" },
      bailDetails: { type: String, default: "" },
      claimAmount: { type: Number, default: null },
      documentType: { type: String, default: "" },
      isCriminalLike: { type: Boolean, default: false },

      summary: { type: String, default: "" },

      parties: [
        {
          name: { type: String, default: "" },
          role: { type: String, default: "" },
        },
      ],

      confidence: {
        type: Map,
        of: Number,
        default: {},
      },

      needsReview: { type: [String], default: [] },
    },

    createdCase: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Case",
    },
  },
  {
    timestamps: true,
  }
);

aiSmartCaseSessionSchema.index({ client: 1, updatedAt: -1 });

aiSmartCaseSessionSchema.index({ status: 1, "progress.updatedAt": 1 });

aiSmartCaseSessionSchema.index(
  { client: 1, requestId: 1 },
  {
    unique: true,
    partialFilterExpression: { requestId: { $type: "string" } },
  }
);

module.exports = mongoose.model("AiSmartCaseSession", aiSmartCaseSessionSchema);
