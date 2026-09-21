const mongoose = require("mongoose");

const clientSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      unique: true,
    },
    address: {
      type: String,
      default: "",
    },
    preferredLanguages: [
      {
        type: String,
      },
    ],
    /// Private practice notes an advocate keeps about this client.
    ///
    /// Read access is filtered to the authoring lawyer in
    /// clientController.getNotes - a note written by one advocate is never
    /// returned to another, nor to the client themselves, who has no endpoint
    /// that reads this array.
    ///
    /// The three fields below (case, title, updatedAt) were added after the
    /// fact and are all optional, so notes written before they existed load
    /// unchanged: an older note simply has no case link and no title.
    notes: [
      {
        lawyer: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
        text: String,
        date: { type: Date, default: Date.now },

        /// Optional case this note belongs to. Null for a general note about
        /// the client that is not tied to any one matter.
        case: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "Case",
          default: null,
        },

        /// Optional short heading, so a list of notes is scannable without
        /// rendering the full body of each one.
        title: {
          type: String,
          default: "",
        },

        updatedAt: {
          type: Date,
          default: Date.now,
        },
      },
    ],
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model("Client", clientSchema);
