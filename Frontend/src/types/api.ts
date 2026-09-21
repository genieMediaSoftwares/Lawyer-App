/**
 * The shapes the Genie Law backend actually sends.
 *
 * Every type here was read off the running server, not inferred from the
 * frontend's wishes. Where the backend is inconsistent — and it is, in one
 * place — the type records the inconsistency rather than papering over it, so
 * the handling is visible at the call site.
 *
 * Success  (src/config/ApiResponse.js)
 *   { "success": true, "message": string, "data": T | null }
 *
 * Failure  (src/middleware/errorMiddleware.js)
 *   { "success": false, "message": string, "code"?: string, "fields"?: {...} }
 *
 * Validation failure  (src/middleware/validationMiddleware.js) — a different
 * shape from every other failure, with express-validator's array attached:
 *   { "success": false, "message": "Validation Failed", "errors": [...] }
 */

export interface ApiSuccess<T> {
  success: true;
  message: string;
  data: T;
}

/** One entry of express-validator's `errors` array. */
export interface ApiValidationIssue {
  type: string;
  value?: unknown;
  msg: string;
  /** The request-body field that failed, e.g. "email". */
  path: string;
  location: string;
}

export interface ApiFailure {
  success: false;
  message: string;
  /** Stable machine-readable code — see backend src/utils/authCodes.js. */
  code?: string;
  /** Per-field messages, sent by the Mongoose validation translator. */
  fields?: Record<string, string>;
  /** Sent only by the express-validator middleware. */
  errors?: ApiValidationIssue[];
}

/**
 * The backend's authentication error codes, copied from
 * backend/src/utils/authCodes.js. Codes are append-only there; nothing may be
 * invented here.
 */
export const AuthCode = {
  EMAIL_ALREADY_REGISTERED: 'EMAIL_ALREADY_REGISTERED',
  MOBILE_ALREADY_REGISTERED: 'MOBILE_ALREADY_REGISTERED',
  NAME_ALREADY_IN_USE: 'NAME_ALREADY_IN_USE',
  INVALID_CREDENTIALS: 'INVALID_CREDENTIALS',
  ACTIVE_SESSION_EXISTS: 'ACTIVE_SESSION_EXISTS',
  SESSION_EXPIRED: 'SESSION_EXPIRED',
  ACCOUNT_INACTIVE: 'ACCOUNT_INACTIVE',
  /** Emitted by the rate limiters in backend/src/app.js. */
  RATE_LIMITED: 'RATE_LIMITED',
} as const;

export type AuthCodeValue = (typeof AuthCode)[keyof typeof AuthCode];
