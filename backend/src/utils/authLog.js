const logger = require("./logger");

/**
 * Authentication event log.
 *
 * Wraps the structured logger with one rule: a secret must never reach it.
 * Auth code handles passwords, access tokens, refresh tokens and reset codes,
 * and a log line is the easiest place for one of them to escape — into a file,
 * a shipper, and a retention window measured in months.
 *
 * Rather than trusting each call site to remember, the filter below drops any
 * field whose name looks like a credential, and truncates anything long enough
 * to be a token that slipped through under an innocent name. Identifiers are
 * kept: a session id is not a bearer credential, and without it these lines
 * could not be correlated to anything.
 */

/** Field names never emitted, whatever they contain. */
const FORBIDDEN_KEYS =
  /(password|passwd|secret|token|authorization|auth|credential|otp|code|hash|pin)/i;

/** Long opaque values are treated as credentials regardless of their key. */
const MAX_VALUE_LENGTH = 64;

const sanitise = (meta = {}) => {
  const safe = {};

  for (const [key, value] of Object.entries(meta)) {
    // `sessionId` and `refreshTokenRotated` would both be caught by the key
    // filter, and the first is exactly what makes these logs useful, so the
    // allow-list is checked first.
    const isAllowedId = /^(sessionId|userId)$/.test(key);

    if (!isAllowedId && FORBIDDEN_KEYS.test(key)) {
      continue;
    }

    if (typeof value === "string" && value.length > MAX_VALUE_LENGTH) {
      safe[key] = `${value.slice(0, 8)}…(${value.length} chars)`;
      continue;
    }

    safe[key] = value;
  }

  return safe;
};

/**
 * @param {string} event  LOGIN_SUCCESS, LOGIN_FAILED, SESSION_CREATED,
 *                        SESSION_REVOKED, REFRESH_SUCCESS, REFRESH_FAILED,
 *                        LOGOUT_SUCCESS.
 */
const authLog = (event, meta = {}) => {
  const failed = /FAILED/.test(event);
  const line = `AUTH ${event}`;

  if (failed) {
    logger.warn(line, sanitise(meta));
    return;
  }

  logger.info(line, sanitise(meta));
};

module.exports = authLog;
module.exports.sanitise = sanitise;
