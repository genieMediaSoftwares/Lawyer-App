const mongoose = require("mongoose");

const referralSchema = new mongoose.Schema(
  {
    referrer: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    referee: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    refereeName: {
      type: String,
      required: true,
    },
    refereeEmail: {
      type: String,
      required: true,
    },
    refereePhone: {
      type: String,
      default: "",
    },
    referrerRole: {
      type: String,
      enum: ["client", "lawyer", "admin"],
      required: true,
    },
    status: {
      type: String,
      enum: ["pending", "accepted", "registered", "completed"],
      default: "pending",
    },
    referralCode: {
      type: String,
      required: true,
    },
    referralLink: {
      type: String,
      default: "",
    },
    source: {
      type: String,
      default: "link",
    },
    registeredAt: {
      type: Date,
    },
    completedAt: {
      type: Date,
    },
    metadata: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
  },
  { timestamps: true }
);

referralSchema.index({ referralCode: 1 });
referralSchema.index({ referrer: 1, createdAt: -1 });

module.exports = mongoose.model("Referral", referralSchema);
