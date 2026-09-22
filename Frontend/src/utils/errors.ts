import axios from 'axios';
import { Platform } from 'react-native';

import { AuthCode } from '../types/api';
import type { ApiFailure } from '../types/api';

export interface AppErrorInfo {
  message: string;
  code?: string;
  status?: number;
  fieldErrors?: Record<string, string>;
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
// A browser hides the real cause of a failed upload. Sizes are checked before
// sending, so treat it as a connection problem first.
const UPLOAD_BLOCKED =
  'The upload could not be completed. Check your connection and try again.';

const looksLikeInternals = (message: string): boolean =>
  /\b(E11000|MongoError|ValidationError|CastError|at\s+\w+\s+\(|node_modules|\/src\/|Error:\s)/i.test(
    message,
  );

const isOnlineBrowser = (): boolean =>
  Platform.OS === 'web' &&
  (globalThis as { navigator?: { onLine?: boolean } }).navigator?.onLine !== false;

const isApiFailure = (body: unknown): body is ApiFailure =>
  typeof body === 'object' &&
  body !== null &&
  'success' in body &&
  (body as { success: unknown }).success === false &&
  typeof (body as { message?: unknown }).message === 'string';

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

const fromValidationArray = (
  body: ApiFailure,
): Pick<AppErrorInfo, 'message' | 'fieldErrors'> | null => {
  if (!Array.isArray(body.errors) || body.errors.length === 0) {
    return null;
  }

  const fieldErrors: Record<string, string> = {};
  for (const issue of body.errors) {
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

    if (!response) {
      if (code === 'ECONNABORTED' || code === 'ETIMEDOUT') {
        return { message: TIMEOUT, isNetworkError: true };
      }
      if (code === 'ERR_NETWORK') {
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
        fieldErrors: body.fields,
        isNetworkError: false,
      };
    }

    return { message: messageForStatus(status), status, isNetworkError: false };
  }

  if (error instanceof Error && error.message && !looksLikeInternals(error.message)) {
    return { message: error.message, isNetworkError: false };
  }

  return { message: GENERIC, isNetworkError: false };
};

export const isSessionEnded = (error: AppErrorInfo): boolean =>
  error.status === 401 || error.code === AuthCode.SESSION_EXPIRED;
