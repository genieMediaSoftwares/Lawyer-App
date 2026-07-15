const mongoose = require("mongoose");

const lawyerSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      unique: true,
    },

    specialization: {
      type: String,
      required: true,
    },

    experience: {
      type: Number,
      default: 0,
    },

    education: {
      type: String,
      default: "",
    },

    barCouncilNumber: {
      type: String,
      default: "",
    },

    languages: [
      {
        type: String,
      },
    ],

    consultationFee: {
      type: Number,
      default: 0,
    },

    bio: {
      type: String,
      default: "",
    },

    officeAddress: {
      type: String,
      default: "",
    },

    availability: [
      {
        day: String,
        startTime: String,
        endTime: String,
      },
    ],

    rating: {
      type: Number,
      default: 0,
    },

    totalReviews: {
      type: Number,
      default: 0,
    },
    upiId: {
      type: String,
      default: "",
    },
    bankDetails: {
      accountHolderName: { type: String, default: "" },
      accountNumber: { type: String, default: "" },
      ifscCode: { type: String, default: "" },
      bankName: { type: String, default: "" },
    },
    barCertificate: {
      type: String,
      default: "",
    },
    verificationStatus: {
      type: String,
      enum: ["pending", "verified", "rejected"],
      default: "pending",
    },
    subscriptionPlan: {
      type: String,
      enum: ["Free", "Basic", "Premium", "Pro Hub"],
      default: "Free",
    },
    googleConnected: {
      type: Boolean,
      default: false,
    },
    googleEmail: {
      type: String,
      default: "",
    },
    googleAccessToken: {
      type: String,
      default: "",
    },
    googleRefreshToken: {
      type: String,
      default: "",
    },
    googleTokenExpiry: {
      type: Date,
    },
    workingHours: {
      type: String,
      default: "9:00 AM - 6:00 PM",
    },
    casesHandled: {
      type: Number,
      default: 120,
    },
    winPercentage: {
      type: Number,
      default: 85,
    },
  },
  {
    timestamps: true,
  }
);

lawyerSchema.index({ user: 1 });
lawyerSchema.index({ rating: -1 });
lawyerSchema.index({ experience: -1 });

module.exports = mongoose.model("Lawyer", lawyerSchema);