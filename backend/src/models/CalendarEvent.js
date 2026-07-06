const mongoose = require("mongoose");

const calendarEventSchema = new mongoose.Schema(
  {
    lawyer: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    title: {
      type: String,
      required: true,
    },
    type: {
      type: String,
      enum: ["holiday", "blocked_date", "personal_event"],
      default: "blocked_date",
    },
    date: {
      type: Date,
      required: true,
    },
    timeSlot: {
      type: String,
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model("CalendarEvent", calendarEventSchema);
