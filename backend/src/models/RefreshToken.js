const mongoose = require("mongoose");

const refreshTokenSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    token: {
      type: String,
      required: true,
      unique: true,
    },
    /**
     * SHA-256 of the device's current refresh token. The raw value is returned
     * to the client once, at issue, and never stored — a database disclosure
     * yields nothing that can be presented back to the server.
     *
     * Rotated in place on every successful refresh, which is also what makes a
     * replayed (already-spent) token fail to match anything.
     */
    refreshTokenHash: {
      type: String,
      default: "",
      index: true,
    },
    /** Stable id for the installation this session belongs to. */
    deviceInfo: {
      type: String,
      default: "unknown",
    },
    /** Human-readable label for the account's session list, e.g. "Pixel 8". */
    deviceName: {
      type: String,
      default: "",
    },
    /** "android", "ios", "web". */
    platform: {
      type: String,
      default: "",
    },
    userAgent: {
      type: String,
      default: "",
    },
    lastUsedAt: {
      type: Date,
      default: Date.now,
    },
    revokedAt: {
      type: Date,
      default: null,
    },
    ipAddress: {
      type: String,
      default: "",
    },
    expiresAt: {
      type: Date,
      required: true,
    },
    isRevoked: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

refreshTokenSchema.index({ user: 1 });
// No explicit index on `token`: `unique: true` on the field already builds one,
// and declaring it twice made Mongoose warn on every boot once this model
// started being loaded.
refreshTokenSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

module.exports = mongoose.model("RefreshToken", refreshTokenSchema);
