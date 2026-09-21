/**
 * Stable machine-readable codes for authentication failures.
 *
 * The client used to have nothing but the human-readable message to work from,
 * so it could not tell a duplicate-signup rejection from a wrong password from
 * a rate-limit block — every one of them arrived as a string and was shown
 * verbatim. Any wording change on this side then silently changed client
 * behaviour. These codes travel alongside the message in the error body
 * (see errorMiddleware) and are what Flutter branches on.
 *
 * Codes are append-only: never repurpose one, because an older app build may
 * still be matching on it.
 */
const AUTH_CODES = {
  /** Signup: the email is already attached to an account. */
  EMAIL_ALREADY_REGISTERED: "EMAIL_ALREADY_REGISTERED",

  /** Signup: the mobile number is already attached to an account. */
  MOBILE_ALREADY_REGISTERED: "MOBILE_ALREADY_REGISTERED",

  /** Signup: the display name is taken. Only ever emitted when unique names
   *  are switched on — see authService.register. */
  NAME_ALREADY_IN_USE: "NAME_ALREADY_IN_USE",

  /** Login: no such user, or the password did not match. Deliberately one
   *  code for both, so the response is not a user-enumeration oracle. */
  INVALID_CREDENTIALS: "INVALID_CREDENTIALS",

  /** Login: the account already holds a live session on a different device. */
  ACTIVE_SESSION_EXISTS: "ACTIVE_SESSION_EXISTS",

  /** Any authenticated request: the session behind this token was revoked
   *  (signed out elsewhere) or has expired. */
  SESSION_EXPIRED: "SESSION_EXPIRED",

  /** Account disabled by an administrator. */
  ACCOUNT_INACTIVE: "ACCOUNT_INACTIVE",
};

module.exports = AUTH_CODES;
