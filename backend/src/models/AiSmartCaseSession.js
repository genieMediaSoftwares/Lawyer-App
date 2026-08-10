const mongoose = require("mongoose");

const aiSmartCaseSessionSchema = new mongoose.Schema(
  {
    client: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    /// Client-supplied idempotency key (`X-Request-Id`) for the upload that
    /// created this session.
    ///
    /// A mobile client that loses the response to `POST /analyze` cannot tell
    /// whether the upload landed, so it retries — and without a key that retry
    /// started a second analysis of the same documents, billed twice and left
    /// two rows in the client's history. The unique index below, scoped to the
    /// client, makes the retry return the original session instead.
    requestId: {
      type: String,
      default: undefined,
    },

    // A session is created as "processing" the moment the upload lands, before
    // any AI work starts, so the client has a real id to subscribe to and the
    // run survives the client disconnecting. It ends as "extracted" or
    // "failed".
    status: {
      type: String,
      enum: ["processing", "extracted", "failed"],
      default: "processing",
    },

    /// Live pipeline position, written at every stage transition.
    ///
    /// This is the authoritative progress record. Socket events are derived
    /// from it rather than the other way round, so a client that missed events
    /// (backgrounded, reconnected, switched devices) can GET the session and
    /// render exactly the same state.
    progress: {
      /// Machine-readable stage id — see PIPELINE_STAGES in
      /// services/ai/aiSmartCasePipeline.js.
      stage: { type: String, default: "queued" },
      /// Human-readable line shown in the UI, e.g. "Reading document 2 of 5".
      message: { type: String, default: "" },
      /// 0-100. Derived from real stage weights, never from a timer.
      percent: { type: Number, default: 0 },
      /// Position within a repeated stage (document N of M). Null otherwise.
      current: { type: Number, default: null },
      total: { type: Number, default: null },
      updatedAt: { type: Date, default: Date.now },
    },

    /// Why the run failed, surfaced to the client verbatim.
    failureReason: {
      type: String,
      default: "",
    },

    /// Per-document and coercion notes (unreadable pages, unmatched category,
    /// failed transcription). Persisted so the Post Case form can show them
    /// even when the client reconnects after the run finished.
    warnings: {
      type: [String],
      default: [],
    },

    /// True when a voice note was supplied but could not be transcribed.
    voiceTranscriptionFailed: {
      type: Boolean,
      default: false,
    },

    uploadedDocuments: [
      {
        /// The `Document` collection record created for this file, so the
        /// Post Case form can attach the same document the client already
        /// uploaded instead of asking for it a second time.
        documentId: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "Document",
          default: null,
        },
        originalName: String,
        mimeType: String,
        size: Number,
        path: String,
        url: String,
        documentType: { type: String, default: "Unknown" },
        ocrQuality: { type: String, default: "Good" },
      },
    ],

    ocrExtractedText: {
      type: String,
      default: "",
    },

    /// The transcript the extraction actually used.
    ///
    /// Normally produced on the client's device while they were speaking, which
    /// is why the pipeline no longer has to transcribe before it can extract.
    voiceTranscript: {
      type: String,
      default: "",
    },

    /// Where `voiceTranscript` came from.
    ///
    /// "live"   — transcribed on the device as the client spoke.
    /// "server" — transcribed here from the uploaded audio, the path taken by
    ///            devices with no speech recogniser.
    /// "none"   — no voice note, or nothing could be transcribed.
    voiceTranscriptSource: {
      type: String,
      enum: ["none", "live", "server"],
      default: "none",
    },

    /// The server's own transcription of the audio, produced after the analysis
    /// finished when a live transcript was supplied alongside the recording.
    ///
    /// Kept for validation and audit only — it is never substituted for what
    /// the client reviewed and submitted.
    serverVoiceTranscript: {
      type: String,
      default: "",
    },

    /// The structured field values handed to the Post Case form.
    ///
    /// Replaces the old `aiAnalysis` blob (title/category/priority plus
    /// timeline, readiness score, follow-up questions and fraud flags) together
    /// with `userAnswers`, `duplicateCheck` and `recommendedLawyers` — all of
    /// which existed only to feed the deleted Review & Confirm screen and its
    /// lawyer recommendations.
    extractedData: {
      title: { type: String, default: "" },
      description: { type: String, default: "" },
      category: { type: String, default: "" },
      categoryId: { type: String, default: "" },
      subType: { type: String, default: "" },
      urgency: { type: String, default: "" },
      city: { type: String, default: "" },
      state: { type: String, default: "" },
      location: { type: String, default: "" },
      court: { type: String, default: "" },
      incidentDate: { type: Date, default: null },
      opposingParty: { type: String, default: "" },
      firNumber: { type: String, default: "" },
      policeStation: { type: String, default: "" },
      bailDetails: { type: String, default: "" },
      claimAmount: { type: Number, default: null },
      documentType: { type: String, default: "" },
      isCriminalLike: { type: Boolean, default: false },

      /// Neutral factual synopsis of the matter, distinct from `description`:
      /// the description is what the client will file, the summary is what the
      /// AI understood, shown read-only for review.
      summary: { type: String, default: "" },

      /// Every party the documents name, with the role each plays. Feeds the
      /// "Other Party" field and is shown in full on the review step.
      parties: [
        {
          name: { type: String, default: "" },
          role: { type: String, default: "" },
        },
      ],

      /// Per-field 0-1 confidence from the model. The form pre-fills only
      /// fields at or above CONFIDENCE_FLOOR and flags the rest for review,
      /// which is what keeps a low-confidence guess out of a filed case.
      confidence: {
        type: Map,
        of: Number,
        default: {},
      },

      /// Field names the client should check before submitting — low
      /// confidence, or extracted from a document whose OCR was degraded.
      needsReview: { type: [String], default: [] },
    },

    createdCase: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Case",
    },
  },
  {
    timestamps: true,
  }
);

aiSmartCaseSessionSchema.index({ client: 1, updatedAt: -1 });

// Drives both the abandoned-run sweep (`status: "processing"` older than the
// pipeline budget) and the per-client concurrency count, which run on every
// analyze request.
aiSmartCaseSessionSchema.index({ status: 1, "progress.updatedAt": 1 });

// Idempotency. Partial rather than sparse so it only constrains documents that
// actually carry a key — sessions created before this field existed, and any
// created without one, are unaffected and can coexist freely.
aiSmartCaseSessionSchema.index(
  { client: 1, requestId: 1 },
  {
    unique: true,
    partialFilterExpression: { requestId: { $type: "string" } },
  }
);

module.exports = mongoose.model("AiSmartCaseSession", aiSmartCaseSessionSchema);
