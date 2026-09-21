import axios from 'axios';
import { Platform } from 'react-native';

import { AuthCode } from '../types/api';
import type { ApiFailure } from '../types/api';

/**
 * Turns anything a request can fail with into something a person can read.
 *
 * The backend is careful never to send a stack trace or a driver message — its
 * error middleware rewrites those — but "careful" is not "guaranteed", and a
 * proxy or a gateway in front of it is under no such discipline. So nothing
 * from the wire is shown verbatim unless it came from a response this app
 * recognises as the backend's own JSON envelope.
 *
 * `fieldErrors` carries per-input messages when the backend sent any, so a
 * form can mark the offending field instead of printing one sentence above it.
 */
export interface AppErrorInfo {
  /** The sentence to show the user. */
  message: string;
  /** The backend's machine-readable code, when it sent one. */
  code?: string;
  /** HTTP status, when the request reached the server at all. */
  status?: number;
  /** Per-field messages, keyed by request-body field name. */
  fieldErrors?: Record<string, string>;
  /** True when the request never got an answer — offline, DNS, timeout. */
  isNetworkError: boolean;
}

const GENERIC =
  'Something went wrong. Please try again.';
const OFFLINE =
  'No internet connection. Check your network and try again.';
const TIMEOUT =
  'The server is taking too long to respond. Please try again.';
const UNREACHABLE =
  'Could not reach the server. Please try again in a moment.';
const TOO_LARGE =
  'These files are too large for the server to accept. Try fewer or smaller files.';
const UPLOAD_BLOCKED =
  'The upload was rejected before it reached the server. This usually means ' +
  'the files are larger than the server currently accepts — try fewer or ' +
  'smaller files.';

/** Never show a message that looks like it escaped from a server log. */
const looksLikeInternals = (message: string): boolean =>
  /\b(E11000|MongoError|ValidationError|CastError|at\s+\w+\s+\(|node_modules|\/src\/|Error:\s)/i.test(
    message,
  );

/** True on web when the browser reports a live connection. */
const isOnlineBrowser = (): boolean =>
  Platform.OS === 'web' &&
  (globalThis as { navigator?: { onLine?: boolean } }).navigator?.onLine !== false;

const isApiFailure = (body: unknown): body is ApiFailure =>
  typeof body === 'object' &&
  body !== null &&
  'success' in body &&
  (body as { success: unknown }).success === false &&
  typeof (body as { message?: unknown }).message === 'string';

/**
 * Messages that replace the backend's own wording.
 *
 * Only where the backend's phrasing is aimed at an operator rather than a
 * user, or where a status carries no useful body at all. Everything else keeps
 * the server's text: it is written for users and it is the single source of
 * truth for what actually happened.
 */
const messageForStatus = (status: number): string => {
  switch (status) {
    case 401:
      return 'Your session has ended. Please sign in again.';
    case 403:
      return 'You do not have permission to do that.';
    case 404:
      return 'We could not find what you were looking for.';
    case 409:
      return 'That record already exists.';
    case 413:
      // Sent by the reverse proxy, not the backend (multer answers 400 for an
      // oversized file), so it arrives as an HTML page with no envelope.
      return TOO_LARGE;
    case 429:
      return 'Too many attempts. Please wait a moment and try again.';
    case 500:
      return 'The server ran into a problem. Please try again.';
    case 502:
    case 503:
    case 504:
      return 'The service is temporarily unavailable. Please try again shortly.';
    default:
      return GENERIC;
  }
};

/**
 * Collapses express-validator's array into one message per field.
 *
 * That middleware answers with a shape nothing else uses — `errors: [{path,
 * msg}]` and the message "Validation Failed", which is not a sentence to show
 * anyone. The individual `msg` values are written for users ("Enter a valid
 * 10-digit mobile number") and are exactly what the form should display.
 */
const fromValidationArray = (
  body: ApiFailure,
): Pick<AppErrorInfo, 'message' | 'fieldErrors'> | null => {
  if (!Array.isArray(body.errors) || body.errors.length === 0) {
    return null;
  }

  const fieldErrors: Record<string, string> = {};
  for (const issue of body.errors) {
    // First message per field wins; later ones for the same field are
    // refinements of the same problem.
    if (issue.path && !fieldErrors[issue.path]) {
      fieldErrors[issue.path] = issue.msg;
    }
  }

  const first = body.errors[0]?.msg;

  return {
    message: first && !looksLikeInternals(first) ? first : GENERIC,
    fieldErrors,
  };
};

export const toAppError = (error: unknown): AppErrorInfo => {
  if (axios.isAxiosError(error)) {
    const { response, code } = error;

    // No response: the request never reached the backend, or never came back.
    if (!response) {
      if (code === 'ECONNABORTED' || code === 'ETIMEDOUT') {
        return { message: TIMEOUT, isNetworkError: true };
      }
      if (code === 'ERR_NETWORK') {
        // In a browser, a proxy rejection (e.g. nginx's 413 for a body over
        // `client_max_body_size`) carries no CORS header, so the browser hides
        // the response and axios sees only ERR_NETWORK. Reporting that as
        // "no internet connection" sent people checking their Wi-Fi. When the
        // browser says it is online and the failed request was an upload, say
        // what most likely happened instead. Native has no CORS: there the 413
        // arrives as a real response and is handled by messageForStatus.
        if (isOnlineBrowser() && error.config?.data instanceof FormData) {
          return { message: UPLOAD_BLOCKED, isNetworkError: true };
        }
        return { message: OFFLINE, isNetworkError: true };
      }
      return { message: UNREACHABLE, isNetworkError: true };
    }

    const status = response.status;
    const body = response.data;

    if (isApiFailure(body)) {
      const validation = fromValidationArray(body);
      if (validation) {
        return {
          ...validation,
          code: body.code,
          status,
          isNetworkError: false,
        };
      }

      const message = looksLikeInternals(body.message)
        ? messageForStatus(status)
        : body.message;

      return {
        message,
        code: body.code,
        status,
        // The Mongoose translator's per-field map, when present.
        fieldErrors: body.fields,
        isNetworkError: false,
      };
    }

    // HTML from a proxy, an empty body, or anything else that is not the
    // backend's envelope. The status is the only thing worth trusting.
    return { message: messageForStatus(status), status, isNetworkError: false };
  }

  if (error instanceof Error && error.message && !looksLikeInternals(error.message)) {
    return { message: error.message, isNetworkError: false };
  }

  return { message: GENERIC, isNetworkError: false };
};

/**
 * Whether a failure means the session is gone and the user must sign in again.
 *
 * Used by the interceptor to decide between refreshing and signing out, and by
 * the store to avoid showing a session error on a screen the user is about to
 * be navigated away from.
 */
export const isSessionEnded = (error: AppErrorInfo): boolean =>
  error.status === 401 || error.code === AuthCode.SESSION_EXPIRED;
