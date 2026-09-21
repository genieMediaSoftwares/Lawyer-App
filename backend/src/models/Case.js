const mongoose = require("mongoose");

const REQUIRED_LAWYER_COUNT = 3;
const LAWYER_REQUEST_STATUSES = ["Pending", "Accepted", "Declined", "Unavailable"];

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

    locationPlaceId: {
      type: String,
      default: "",
    },
    locationLongitude: {
      type: Number,
      default: 0.0,
    },

    preferredCourt: {
      type: String,
      default: "",
    },

    incidentDate: {
      type: Date,
      default: null,
    },

    opposingParty: {
      type: String,
      default: "",
    },

    firNumber: {
      type: String,
      default: "",
    },

    policeStation: {
      type: String,
      default: "",
    },

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

    lawyerRequests: {
      type: [
        {
          _id: false,
          lawyer: {
            type: mongoose.Schema.Types.ObjectId,
            ref: "User",
            required: true,
          },
          status: {
            type: String,
            enum: LAWYER_REQUEST_STATUSES,
            default: "Pending",
          },
          createdAt: {
            type: Date,
            default: Date.now,
          },
          respondedAt: {
            type: Date,
            default: null,
          },
          acceptedAt: {
            type: Date,
            default: null,
          },
        },
      ],
      default: [],
      validate: {
        validator: (requests) => {
          if (requests.length === 0) return true;
          const ids = new Set(requests.map((r) => r.lawyer.toString()));
          return requests.length === REQUIRED_LAWYER_COUNT && ids.size === requests.length;
        },
        message: `Exactly ${REQUIRED_LAWYER_COUNT} different lawyers must be selected.`,
      },
    },

    clientRequestId: {
      type: String,
      default: undefined,
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

    hearings: [
      {
        date: {
          type: Date,
          required: true,
        },

        timeSlot: {
          type: String,
          default: "",
        },

        court: {
          type: String,
          default: "",
        },

        purpose: {
          type: String,
          default: "",
        },

        status: {
          type: String,
          enum: ["scheduled", "completed", "adjourned", "cancelled"],
          default: "scheduled",
        },

        notes: {
          type: String,
          default: "",
        },

        createdBy: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "User",
        },

        createdAt: {
          type: Date,
          default: Date.now,
        },

        updatedAt: {
          type: Date,
          default: Date.now,
        },
      },
    ],

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
caseSchema.index({ assignedLawyer: 1, "hearings.date": 1 });
caseSchema.index({ category: 1, locationCity: 1 });
caseSchema.index({ locationState: 1 });
caseSchema.index({ createdAt: -1 });
caseSchema.index({ updatedAt: -1 });
caseSchema.index({ "lawyerRequests.lawyer": 1, "lawyerRequests.status": 1 });
caseSchema.index(
  { client: 1, clientRequestId: 1 },
  { unique: true, partialFilterExpression: { clientRequestId: { $type: "string" } } }
);

module.exports = mongoose.model("Case", caseSchema);
module.exports.REQUIRED_LAWYER_COUNT = REQUIRED_LAWYER_COUNT;
module.exports.LAWYER_REQUEST_STATUSES = LAWYER_REQUEST_STATUSES;
