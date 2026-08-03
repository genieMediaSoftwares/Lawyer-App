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

    locationCity: {
      type: String,
      default: "",
    },

    locationDistrict: {
      type: String,
      default: "",
    },

    locationState: {
      type: String,
      default: "",
    },

    locationCountry: {
      type: String,
      default: "",
    },

    locationLatitude: {
      type: Number,
      default: 0.0,
    },

    locationLongitude: {
      type: Number,
      default: 0.0,
    },

    preferredCourt: {
      type: String,
      default: "",
    },

    // ── Structured detail extracted from uploaded documents ──────────────────
    // Populated by the AI intake extractor and editable by the client on the
    // Post Case form before submission. All optional: a case can be filed with
    // nothing more than a category, location and description.

    /// Date the incident occurred (not the filing date). Relevant to almost
    /// every category, so always collected.
    incidentDate: {
      type: Date,
      default: null,
    },

    /// The other side — respondent, opposing party, builder, employer, bank.
    /// Free text because it may be a person, a company, or several of both.
    opposingParty: {
      type: String,
      default: "",
    },

    // The three below only apply to Criminal Law, Cyber Crime and Motor
    // Accident Claims (3 of 15 categories), so the form reveals them
    // conditionally rather than showing empty inputs on a GST or divorce case.

    /// FIR number, or an existing court case number if proceedings started.
    firNumber: {
      type: String,
      default: "",
    },

    policeStation: {
      type: String,
      default: "",
    },

    /// Bail status/type and any sections charged, as free text. Deliberately
    /// unmodelled: sections vary by statute (IPC/BNS, NDPS, POCSO...) and a
    /// rigid sub-schema would reject real-world combinations.
    bailDetails: {
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

    voiceUrl: {
      type: String,
      default: "",
    },

    voiceTranscript: {
      type: String,
      default: "",
    },
  },
  {
    timestamps: true,
  }
);

caseSchema.index({ client: 1, status: 1, createdAt: -1 });
caseSchema.index({ assignedLawyer: 1, status: 1 });
caseSchema.index({ category: 1, locationCity: 1 });
caseSchema.index({ createdAt: -1 });
caseSchema.index({ updatedAt: -1 });

module.exports = mongoose.model("Case", caseSchema);
