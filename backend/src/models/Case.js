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

    /// Google Places id for the selected city, kept so a stored location can
    /// be re-resolved later (coordinates, canonical name) without asking the
    /// client to pick it again. Empty on cases filed before this was captured.
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

    /// Court hearings listed on this case.
    ///
    /// Embedded on Case rather than given its own collection: a hearing has no
    /// meaning apart from its case, is always read together with it, and every
    /// existing reader already reaches the case first. A separate collection
    /// would have added a join to paths that currently need none.
    ///
    /// This does NOT replace nextHearing above. That field predates the array
    /// and is read by the client My Cases screen, the lawyer Clients tab and
    /// /lawyers/schedule/today. The controller keeps it mirrored to the
    /// earliest upcoming scheduled hearing, so those three readers keep
    /// working unchanged, and cases filed before this existed simply carry an
    /// empty array.
    ///
    /// A court hearing is deliberately NOT an Appointment: Appointment models
    /// a lawyer-client consultation (Chat/In-Person, synced to Google
    /// Calendar). The two are distinct in the domain and stay distinct here.
    hearings: [
      {
        date: {
          type: Date,
          required: true,
        },

        /// Free text ("10:30 AM", "Item 42"). Courts do not publish precise
        /// slots, so this is not modelled as a time.
        timeSlot: {
          type: String,
          default: "",
        },

        /// Court name as free text rather than a ref to the Court collection:
        /// that collection is a seeded directory that does not cover every
        /// bench, and a hearing must be recordable at a court missing from it.
        court: {
          type: String,
          default: "",
        },

        /// What the hearing is for - "Framing of charges", "Final arguments".
        purpose: {
          type: String,
          default: "",
        },

        status: {
          type: String,
          enum: ["scheduled", "completed", "adjourned", "cancelled"],
          default: "scheduled",
        },

        /// Outcome or preparation notes. Carries the same visibility as the
        /// rest of the case - this is not the lawyer's private notebook, which
        /// lives on Client.notes and is filtered to its author.
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

module.exports = mongoose.model("Case", caseSchema);
