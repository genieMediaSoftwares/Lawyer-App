const mongoose = require("mongoose");

const caseSchema = new mongoose.Schema(
  {
    client: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    title: {
      type: String,
      required: true,
      trim: true,
    },

    description: {
      type: String,
      required: true,
    },

    category: {
      type: String,
      required: true,
    },

    subcategory: {
      type: String,
      default: "",
    },

    location: {
      type: String,
      required: true,
    },

    preferredCourt: {
      type: String,
      default: "",
    },

    budgetRange: {
      type: String,
      default: "",
    },

    urgency: {
      type: String,
      default: "Flexible",
    },

    status: {
      type: String,
      enum: ["Submitted", "Awaiting Lawyer Acceptance", "Pending Lawyer Response", "Interested", "Accepted", "In Progress", "Closed", "Rejected"],
      default: "Submitted",
    },

    documents: [
      {
        name: String,
        url: String,
        size: String,
      },
    ],

    proposals: [
      {
        lawyer: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "User",
        },
        feeProposal: {
          type: Number,
          required: true,
        },
        message: {
          type: String,
          default: "",
        },
        createdAt: {
          type: Date,
          default: Date.now,
        },
      },
    ],

    selectedLawyer: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
    },

    assignedLawyer: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
    },

    milestones: [
      {
        title: { type: String, required: true },
        date: { type: Date, default: Date.now },
        isCompleted: { type: Boolean, default: false },
      },
    ],

    caseOutcome: {
      type: String,
      default: "",
    },

    claimAmount: {
      type: String,
      default: "",
    },

    consultationDate: {
      type: Date,
      default: null,
    },

    nextHearing: {
      type: Date,
      default: null,
    },

    closedDate: {
      type: Date,
      default: null,
    },

    rating: {
      type: Number,
      default: 0,
    },

    review: {
      type: String,
      default: "",
    },

    acceptedAt: {
      type: Date,
      default: null,
    },

    startedAt: {
      type: Date,
      default: null,
    },

    completedAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

caseSchema.index({ client: 1 });
caseSchema.index({ selectedLawyer: 1 });
caseSchema.index({ assignedLawyer: 1 });
caseSchema.index({ status: 1 });
caseSchema.index({ createdAt: -1 });
caseSchema.index({ updatedAt: -1 });

module.exports = mongoose.model("Case", caseSchema);
