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
    notes: [
      {
        lawyer: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
        text: String,
        date: { type: Date, default: Date.now },
      },
    ],
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model("Client", clientSchema);
