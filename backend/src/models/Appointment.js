const mongoose = require("mongoose");

const appointmentSchema = new mongoose.Schema(
  {
    client: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    lawyer: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    case: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Case",
    },

    date: {
      type: Date,
      required: true,
    },

    timeSlot: {
      type: String,
      required: true,
    },

    mode: {
      type: String,
      enum: ["Chat", "In-Person"],
      default: "Chat",
    },

    status: {
      type: String,
      enum: ["pending", "confirmed", "completed", "cancelled"],
      default: "pending",
    },
    googleCalendarEventId: {
      type: String,
      default: "",
    },
    meetingLink: {
      type: String,
      default: "",
    },
    notes: {
      type: String,
      default: "",
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model("Appointment", appointmentSchema);
