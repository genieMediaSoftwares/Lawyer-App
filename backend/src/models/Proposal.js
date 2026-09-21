const mongoose = require("mongoose");

const proposalSchema = new mongoose.Schema(
  {
    caseId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Case",
      required: true,
    },
    lawyerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    clientId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    consultationFee: {
      type: Number,
      required: true,
    },
    proposalMessage: {
      type: String,
      required: true,
    },
    availability: {
      type: String,
      required: true,
    },
    consultationMode: {
      type: String,
      enum: ["Online", "Offline", "Video"],
      required: true,
    },
    estimatedResponseTime: {
      type: String,
      default: "24 hours",
    },
    status: {
      type: String,
      enum: ["Pending", "Accepted", "Rejected"],
      default: "Pending",
    },
  },
  {
    timestamps: true,
  }
);

proposalSchema.index({ caseId: 1 });
proposalSchema.index({ lawyerId: 1 });
proposalSchema.index({ clientId: 1 });

module.exports = mongoose.model("Proposal", proposalSchema);
