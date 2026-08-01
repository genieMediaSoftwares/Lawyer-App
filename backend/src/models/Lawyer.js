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
    // Every field below describes a lawyer's real track record and is shown to
    // clients choosing legal representation. Each one therefore defaults to
    // "not provided", never to a plausible-looking number.
    //
    // These previously defaulted to "9:00 AM - 6:00 PM", 120 cases and an 85%
    // win rate, so a lawyer who had filled in nothing still presented a
    // complete and flattering record. The API's `winPercentage > 0 ? ... : null`
    // guard could never fire, because the schema had already supplied 85.
    workingHours: {
      type: String,
      default: "",
    },
    casesHandled: {
      type: Number,
      default: 0,
    },
    winPercentage: {
      type: Number,
      default: 0,
    },

    /// Typical time this lawyer takes to respond, in their own words
    /// ("Responds within 2 hours"). Empty until they state one.
    responseTime: {
      type: String,
      default: "",
    },

    /// District, kept separate from the free-text `user.location` so
    /// recommendations can match on it without parsing an address.
    district: {
      type: String,
      default: "",
    },

    /// Areas this lawyer declares they practise, beyond their primary
    /// `specialization`.
    practiceAreas: {
      type: [String],
      default: [],
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