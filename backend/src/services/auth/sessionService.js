const crypto = require("crypto");

const RefreshToken = require("../../models/RefreshToken");

/**
 * Server-side session tracking.
 *
 * Login state used to live entirely in the Flutter secure store: the server
 * signed a JWT and forgot about it. Nothing could answer "is this account
 * signed in right now?", so the active-session check had to be inferred on the
 * client, signing out did not actually end anything, and a token stayed usable
 * for its full 7-day life no matter what the user did. This module is the
 * missing half — one row per live session, written at login and revoked at
 * logout, keyed by the `sid` claim the JWT now carries.
 *
 * It is backed by the existing RefreshToken collection rather than a new one.
 * That schema was already declared and unused, and its fields are exactly a
 * session record — owner, opaque token, device, IP, expiry, revocation flag,
 * plus a TTL index on `expiresAt` that reaps rows Mongo-side. No schema change,
 * no new collection.
 */

/** Falls back to the JWT default used elsewhere if the env value is unusable. */
const DEFAULT_TTL_MS = 7 * 24 * 60 * 60 * 1000;

/**
 * Turns a jsonwebtoken-style duration ("7d", "12h", "900s", or bare seconds)
 * into milliseconds.
 *
 * The session row must not outlive the token it tracks, or a revoked-but-
 * unexpired row lingers; nor may it die first, which would sign the user out
 * while their token is still valid. Deriving both from JWT_EXPIRES_IN keeps
 * them in step.
 */
const parseDurationMs = (value) => {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value * 1000;
  }
  if (typeof value !== "string") {
    return DEFAULT_TTL_MS;
  }

  const match = value.trim().match(/^(\d+(?:\.\d+)?)\s*(ms|s|m|h|d)?$/i);
  if (!match) {
    return DEFAULT_TTL_MS;
  }

  const amount = Number(match[1]);
  const unit = (match[2] || "s").toLowerCase();
  const multipliers = {
    ms: 1,
    s: 1000,
    m: 60 * 1000,
    h: 60 * 60 * 1000,
    d: 24 * 60 * 60 * 1000,
  };

  return amount * multipliers[unit];
};

class SessionService {
  get ttlMs() {
    return parseDurationMs(process.env.JWT_EXPIRES_IN);
  }

  /**
   * The one predicate for "this row is a live session".
   *
   * The TTL index only sweeps every 60 seconds, so an expired row is readable
   * for up to a minute after it should have gone. Every query filters on
   * `expiresAt` as well as `isRevoked` so that window cannot resurrect a dead
   * session — or, worse, make a user look signed-in elsewhere and block their
   * own login.
   */
  _activeFilter(userId) {
    return {
      user: userId,
      isRevoked: false,
      expiresAt: { $gt: new Date() },
    };
  }

  /**
   * The session currently holding this account, or null.
   *
   * Newest first: if an earlier bug ever left two live rows behind, the one the
   * user is actually holding is the one reported.
   */
  async findActiveSession(userId) {
    return RefreshToken.findOne(this._activeFilter(userId)).sort({
      createdAt: -1,
    });
  }

  /**
   * Ends every live session this account holds on `deviceId`.
   *
   * Signing in again from the same handset is a replacement, not a conflict.
   * Without this, the ordinary sequence of killing the app (which never reaches
   * logout) and reopening it would report the user's own stale session as
   * "already logged in on another device" and lock them out of their account
   * until the token expired.
   *
   * @returns {Promise<number>} rows revoked.
   */
  async revokeSessionsForDevice(userId, deviceId) {
    if (!deviceId) {
      return 0;
    }

    const result = await RefreshToken.updateMany(
      { ...this._activeFilter(userId), deviceInfo: deviceId },
      { $set: { isRevoked: true } }
    );

    return result.modifiedCount || 0;
  }

  /** Opens a session and returns its id, which becomes the token's `sid`. */
  async createSession({ userId, deviceId, ipAddress }) {
    const sessionId = crypto.randomUUID();

    await RefreshToken.create({
      user: userId,
      token: sessionId,
      deviceInfo: deviceId || "unknown",
      ipAddress: ipAddress || "",
      expiresAt: new Date(Date.now() + this.ttlMs),
      isRevoked: false,
    });

    return sessionId;
  }

  /**
   * Ends one session. Idempotent — a second logout, or a logout racing an
   * expiry, is not an error.
   */
  async revokeSession(sessionId) {
    if (!sessionId) {
      return false;
    }

    const result = await RefreshToken.updateOne(
      { token: sessionId, isRevoked: false },
      { $set: { isRevoked: true } }
    );

    return (result.modifiedCount || 0) > 0;
  }

  /** Ends every session for an account. Used when the account is deleted. */
  async revokeAllSessions(userId) {
    await RefreshToken.updateMany(
      { user: userId, isRevoked: false },
      { $set: { isRevoked: true } }
    );
  }

  /**
   * Whether a `sid` from a presented token still names a live session.
   *
   * This is what makes logout real: once the row is revoked the token keeps
   * verifying cryptographically but stops being accepted.
   */
  async isSessionActive(sessionId) {
    if (!sessionId) {
      return false;
    }

    const session = await RefreshToken.exists({
      token: sessionId,
      isRevoked: false,
      expiresAt: { $gt: new Date() },
    });

    return Boolean(session);
  }
}

module.exports = new SessionService();
module.exports.parseDurationMs = parseDurationMs;
