const mongoose = require("mongoose");

// A record that one user accepted one version of one document, kept as
// history: accepting a new version never overwrites the previous record.
const legalAcceptanceSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    document: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "LegalDocument",
      required: true,
    },

    // Copied at acceptance time so the record stays readable even if the
    // document is later edited or removed.
    documentType: {
      type: String,
      required: true,
    },

    version: {
      type: String,
      required: true,
    },

    acceptedAt: {
      type: Date,
      default: Date.now,
    },

    appVersion: {
      type: String,
      default: "",
    },
  },
  { timestamps: true }
);

legalAcceptanceSchema.index(
  { user: 1, documentType: 1, version: 1 },
  { unique: true }
);

module.exports = mongoose.model("LegalAcceptance", legalAcceptanceSchema);
