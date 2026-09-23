const mongoose = require("mongoose");

// The documents a user may have to read or accept. Content is authored and
// published by the platform operator (legal review is theirs, not the app's):
// nothing here writes or generates legal text.
const LEGAL_DOCUMENT_TYPES = [
  "platform_terms",
  "client_terms",
  "lawyer_terms",
  "privacy_policy",
  "refund_policy",
  "ai_disclaimer",
  "communication_consent",
  "document_sharing_consent",
];

const AUDIENCES = ["all", "client", "lawyer"];

const legalDocumentSchema = new mongoose.Schema(
  {
    type: {
      type: String,
      enum: LEGAL_DOCUMENT_TYPES,
      required: true,
    },

    // Free-form so the operator can use whatever scheme they publish under
    // (e.g. "1.0", "2026-09-01").
    version: {
      type: String,
      required: true,
      trim: true,
    },

    title: {
      type: String,
      required: true,
      trim: true,
    },

    content: {
      type: String,
      required: true,
    },

    effectiveDate: {
      type: Date,
      required: true,
    },

    audience: {
      type: String,
      enum: AUDIENCES,
      default: "all",
    },

    // Only one version of a type is active at a time; the rest stay for history.
    isActive: {
      type: Boolean,
      default: false,
    },

    // When true, users in the audience are asked to accept this version.
    requiresAcceptance: {
      type: Boolean,
      default: false,
    },

    // Set by the operator when the text has been through legal review, so the
    // app can tell a published document from an unreviewed placeholder.
    legallyReviewed: {
      type: Boolean,
      default: false,
    },
  },
  { timestamps: true }
);

legalDocumentSchema.index({ type: 1, version: 1 }, { unique: true });
legalDocumentSchema.index({ type: 1, isActive: 1 });

module.exports = mongoose.model("LegalDocument", legalDocumentSchema);
module.exports.LEGAL_DOCUMENT_TYPES = LEGAL_DOCUMENT_TYPES;
module.exports.AUDIENCES = AUDIENCES;
