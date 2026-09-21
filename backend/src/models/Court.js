const mongoose = require("mongoose");

const courtSchema = new mongoose.Schema(
  {
    courtName: {
      type: String,
      required: true,
      trim: true,
    },
    courtType: {
      type: String,
      required: true,
    },
    city: {
      type: String,
      required: true,
      trim: true,
    },
    district: {
      type: String,
      trim: true,
    },
    state: {
      type: String,
      required: true,
      trim: true,
    },
    country: {
      type: String,
      required: true,
      trim: true,
    },
    courtAddress: {
      type: String,
      required: true,
    },
    pincode: {
      type: String,
    },
    latitude: {
      type: Number,
    },
    longitude: {
      type: Number,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model("Court", courtSchema);
