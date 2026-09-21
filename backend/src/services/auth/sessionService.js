const crypto = require("crypto");

const RefreshToken = require("../../models/RefreshToken");

/**
 * Server-side session tracking, one row per signed-in device.
 *
 * Login state used to live entirely in the Flutter secure store: the server
 * signed a JWT and forgot about it. Nothing could answer "is this account
 * signed in right now?", signing out did not actually end anything, and a token
 * stayed usable for its full life no matter what the user did. This module is
 * the missing half — one row per live session, written at login and revoked at
 * logout, keyed by the `sid` claim the JWT carries.
 *
 * It is backed by the existing RefreshToken collection rather than a new one.
 * That schema was already declared and its fields are exactly a session record
 * — owner, opaque id, device, IP, expiry, revocation flag, plus a TTL index on
 * `expiresAt` that reaps rows Mongo-side.
 *
 * Nothing here is scoped to a single device, and nothing here ever was: a user
 * may hold as many rows as they have devices, and every operation names the one
 * session it acts on. The one-device rule that used to exist lived in
 * authService.login, above this layer, and has been removed.
 */

/**
 * Session lifetime when JWT_REFRESH_EXPIRES_IN is unset or unusable.
 *
 * Thirty days, matching the refresh-token lifetime the app is configured for.
 */
const DEFAULT_SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000;

/** Access-token lifetime when JWT_EXPIRES_IN is unset or unusable. */
const DEFAULT_ACCESS_TTL_MS = 15 * 60 * 1000;

/**
 * Turns a jsonwebtoken-style duration ("30d", "12h", "900s", or bare seconds)
 * into milliseconds.
 */
const parseDurationMs = (value, fallback) => {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value * 1000;
  }
  if (typeof value !== "string") {
    return fallback;
  }

  const match = value.trim().match(/^(\d+(?:\.\d+)?)\s*(ms|s|m|h|d)?$/i);
  if (!match) {
    return fallback;
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

/**
 * Refresh tokens are stored as a SHA-256 digest, never in the clear.
 *
 * The value is 256 bits of CSPRNG output, so it carries no structure worth
 * salting and no password-style guessability worth a slow KDF — a plain digest
 * is the right primitive here. A database disclosure then yields nothing that
 * can be presented back to the server.
 */
const hashRefreshToken = (raw) =>
  crypto.createHash("sha256").update(String(raw)).digest("hex");

class SessionService {
  /** How long a session — and so its refresh token — stays usable. */
  get ttlMs() {
    return parseDurationMs(
      process.env.JWT_REFRESH_EXPIRES_IN,
      // Falls back to the access-token setting so a deployment that has not
      // added JWT_REFRESH_EXPIRES_IN yet keeps its previous session lifetime
      // rather than silently dropping to fifteen minutes.
      parseDurationMs(process.env.JWT_EXPIRES_IN, DEFAULT_SESSION_TTL_MS)
    );
  }

  /** Access-token lifetime in seconds, reported to the client as `expiresIn`. */
  get accessTokenTtlSeconds() {
    return Math.floor(
      parseDurationMs(process.env.JWT_EXPIRES_IN, DEFAULT_ACCESS_TTL_MS) / 1000
    );
  }

  /**
   * The one predicate for "this row is a live session".
   *
   * The TTL index only sweeps every 60 seconds, so an expired row is readable
   * for up to a minute after it should have gone. Every query filters on
   * `expiresAt` as well as `isRevoked` so that window cannot resurrect a dead
   * session.
   */
  _activeFilter(userId) {
    return {
      user: userId,
      isRevoked: false,
      expiresAt: { $gt: new Date() },
    };
  }

  /** Every live session an account holds, newest first. */
  async listActiveSessions(userId) {
    return RefreshToken.find(this._activeFilter(userId)).sort({
      createdAt: -1,
    });
  }

  /**
   * Ends every live session this account holds on `deviceId`.
   *
   * Signing in again from the same installation replaces its own session rather
   * than stacking another onto it — otherwise every app restart would leave a
   * row behind. Scoped to one deviceId, so it can never reach another device.
   *
   * @returns {Promise<number>} rows revoked.
   */
  async revokeSessionsForDevice(userId, deviceId) {
    if (!deviceId) {
      return 0;
    }

    const result = await RefreshToken.updateMany(
      { ...this._activeFilter(userId), deviceInfo: deviceId },
      { $set: { isRevoked: true, revokedAt: new Date() } }
    );

    return result.modifiedCount || 0;
  }

  /**
   * Opens a session for one device.
   *
   * Returns the session (whose `sessionId` becomes the token's `sid`) and the
   * raw refresh token. The raw value is returned exactly once, here: only its
   * digest is stored, so it cannot be recovered afterwards.
   */
  async createSession({
    userId,
    deviceId,
    deviceName,
    platform,
    ipAddress,
    userAgent,
  }) {
    const sessionId = crypto.randomUUID();
    const refreshToken = crypto.randomBytes(32).toString("hex");

    await RefreshToken.create({
      user: userId,
      token: sessionId,
      refreshTokenHash: hashRefreshToken(refreshToken),
      deviceInfo: deviceId || "unknown",
      deviceName: deviceName || "",
      platform: platform || "",
      ipAddress: ipAddress || "",
      userAgent: userAgent || "",
      lastUsedAt: new Date(),
      expiresAt: new Date(Date.now() + this.ttlMs),
      isRevoked: false,
    });

    return { session: { sessionId }, refreshToken };
  }

  /**
   * Exchanges a refresh token for a new one, in place, on its own session.
   *
   * Rotation is a single conditional update rather than a read-then-write: the
   * filter names the digest being spent, so two requests racing with the same
   * token produce exactly one winner and the loser matches nothing. That is
   * what keeps a device firing several requests at once — all of which get a
   * 401 together and all of which try to refresh — from corrupting its own
   * session.
   *
   * Only this session is touched. A rotation on one device cannot revoke,
   * rotate or otherwise disturb another.
   *
   * @returns {Promise<{sessionId: string, userId: string, refreshToken: string}|null>}
   *   null when the token is unknown, already spent, revoked or expired.
   */
  async rotateRefreshToken(rawToken) {
    if (!rawToken) {
      return null;
    }

    const nextRefreshToken = crypto.randomBytes(32).toString("hex");
    const now = new Date();

    const session = await RefreshToken.findOneAndUpdate(
      {
        refreshTokenHash: hashRefreshToken(rawToken),
        isRevoked: false,
        expiresAt: { $gt: now },
      },
      {
        $set: {
          refreshTokenHash: hashRefreshToken(nextRefreshToken),
          lastUsedAt: now,
        },
      },
      { new: true }
    );

    if (!session) {
      return null;
    }

    return {
      sessionId: session.token,
      userId: session.user,
      refreshToken: nextRefreshToken,
    };
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
      { $set: { isRevoked: true, revokedAt: new Date() } }
    );

    return (result.modifiedCount || 0) > 0;
  }

  /**
   * Ends every session for an account — "sign out everywhere", and the cleanup
   * performed when an account is deleted.
   *
   * Deliberately separate from [revokeSession]: ordinary logout must never
   * reach this, or signing out of one phone would sign the user out of all of
   * them.
   *
   * @returns {Promise<number>} rows revoked.
   */
  async revokeAllSessions(userId) {
    const result = await RefreshToken.updateMany(
      { user: userId, isRevoked: false },
      { $set: { isRevoked: true, revokedAt: new Date() } }
    );

    return result.modifiedCount || 0;
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
module.exports.hashRefreshToken = hashRefreshToken;
