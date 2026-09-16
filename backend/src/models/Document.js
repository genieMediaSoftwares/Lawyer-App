const mongoose = require("mongoose");

const documentSchema = new mongoose.Schema(
  {
    clientId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    issueId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Issue",
      default: null,
    },
    /**
     * The filename as uploaded. Never changes, so the client can always see
     * what the file was called when it arrived.
     */
    originalName: {
      type: String,
      required: true,
    },
    /**
     * The display name, which the owner may rename. Falls back to
     * `originalName` for documents uploaded before renaming existed — see
     * `displayName()` in documentController, which is the single place that
     * resolves the two.
     *
     * Deliberately NOT unique: two matters can both hold a "Petition.pdf", and
     * the document is identified by its _id everywhere. `fileName` (the
     * on-disk name) is what stays collision-free.
     */
    name: {
      type: String,
      default: "",
      trim: true,
    },
    fileName: {
      type: String,
      required: true,
    },
    filePath: {
      type: String,
      required: true,
    },
    mimeType: {
      type: String,
      required: true,
    },
    fileSize: {
      type: Number,
      required: true,
    },
    uploadedAt: {
      type: Date,
      default: Date.now,
    },
    /**
     * Bumped when the stored bytes are replaced, so the client can tell "I
     * renamed this" from "I swapped the file underneath it". `updatedAt` from
     * timestamps moves on any write, including a rename, so it cannot answer
     * that on its own.
     */
    contentUpdatedAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model("Document", documentSchema);
