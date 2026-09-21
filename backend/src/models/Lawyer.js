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
      enum: ["Free", "Starter", "Professional", "Premium", "Elite", "Basic", "Pro Hub"],
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

    responseTime: {
      type: String,
      default: "",
    },

    district: {
      type: String,
      default: "",
    },

    practiceAreas: {
      type: [String],
      default: [],
    },
  },
  {
    timestamps: true,
  }
);

const { encrypt, decrypt } = require("../utils/cryptoUtil");

lawyerSchema.pre("save", function (next) {
  if (this.upiId) {
    this.upiId = encrypt(this.upiId);
  }
  if (this.bankDetails && this.bankDetails.accountNumber) {
    this.bankDetails.accountNumber = encrypt(this.bankDetails.accountNumber);
  }
  next();
});

function decryptFinancials(doc) {
  if (!doc) return;
  if (doc.upiId) {
    doc.upiId = decrypt(doc.upiId);
  }
  if (doc.bankDetails && doc.bankDetails.accountNumber) {
    doc.bankDetails.accountNumber = decrypt(doc.bankDetails.accountNumber);
  }
}

lawyerSchema.post("init", decryptFinancials);
lawyerSchema.post("save", decryptFinancials);

lawyerSchema.index({ rating: -1 });
lawyerSchema.index({ experience: -1 });
lawyerSchema.index({ specialization: 1, rating: -1 });

module.exports = mongoose.model("Lawyer", lawyerSchema);