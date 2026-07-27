const mongoose = require("mongoose");

const aiSmartCaseSessionSchema = new mongoose.Schema(
  {
    client: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    status: {
      type: String,
      enum: ["processing", "questions_pending", "reviewed", "created", "failed"],
      default: "processing",
    },

    uploadedDocuments: [
      {
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

    aiAnalysis: {
      caseTitle: { type: String, default: "" },
      caseDescription: { type: String, default: "" },
      category: { type: String, default: "General Legal" },
      priority: { type: String, default: "Medium" },
      documentType: { type: String, default: "Document" },
      applicableLegalDomain: { type: String, default: "" },
      requiredSupportingDocuments: [{ type: String }],
      aiConfidenceScore: { type: Number, default: 0 },
      readinessScore: { type: Number, default: 0 },
      detectedTimeline: [{ type: String }],
      lawyerSpecializationRequired: { type: String, default: "" },
      missingInformation: [{ type: String }],
      followUpQuestions: [{ type: String }],
      fraudFlags: [{ type: String }],
    },

    userAnswers: [
      {
        question: String,
        answer: String,
      },
    ],

    duplicateCheck: {
      isDuplicate: { type: Boolean, default: false },
      existingCaseId: { type: mongoose.Schema.Types.ObjectId, ref: "Case" },
      existingCaseTitle: { type: String, default: "" },
      similarityScore: { type: Number, default: 0 },
    },

    recommendedLawyers: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],

    createdCase: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Case",
    },
  },
  {
    timestamps: true,
  }
);

aiSmartCaseSessionSchema.index({ client: 1 });
aiSmartCaseSessionSchema.index({ status: 1 });

module.exports = mongoose.model("AiSmartCaseSession", aiSmartCaseSessionSchema);
