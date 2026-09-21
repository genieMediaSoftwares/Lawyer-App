import axios from 'axios';
import type {
  AxiosError,
  AxiosInstance,
  InternalAxiosRequestConfig,
} from 'axios';

import { env } from '../config/env';
import { tokenStore } from './tokenStore';
import type { ApiSuccess } from '../types/api';
import type { AuthSession } from '../types/auth';

/**
 * The one Axios instance the app talks through.
 *
 * Everything above it — screens, stores, React Query — sees plain functions.
 * Authentication, token renewal and retry live here and nowhere else, so no
 * screen has to know that tokens exist.
 */

/** Paths that must never trigger a token refresh. */
const REFRESH_EXEMPT = [
  // Refreshing on a failed refresh is the infinite loop this guards against.
  '/auth/refresh-token',
  // A 401 here means the password was wrong, not that a token expired.
  '/auth/login',
  '/auth/signup',
  '/auth/forgot-password',
  '/auth/reset-password',
];

/** Our own marker on a retried request, so a retry can never be retried. */
interface RetryableConfig extends InternalAxiosRequestConfig {
  _genieRetry?: boolean;
}

export const apiClient: AxiosInstance = axios.create({
  baseURL: env.apiBaseUrl,
  timeout: env.apiTimeoutMs,
  headers: { 'Content-Type': 'application/json' },
});

/**
 * A second instance, deliberately free of interceptors, used only to spend a
 * refresh token.
 *
 * If the refresh call went through `apiClient`, its own 401 would re-enter the
 * response interceptor and start another refresh — the loop that the exempt
 * list above also guards, belt and braces.
 */
const refreshClient: AxiosInstance = axios.create({
  baseURL: env.apiBaseUrl,
  timeout: env.apiTimeoutMs,
  headers: { 'Content-Type': 'application/json' },
});

// ---------------------------------------------------------------------------
// Request: attach the access token.
// ---------------------------------------------------------------------------

/**
 * Deliberately synchronous, and deliberately sends no X-Device-* headers.
 *
 * The backend reads the device fields in `deviceContext()`
 * (backend/src/controllers/auth/authController.js), which checks `req.body`
 * first and only falls back to the headers. Just two routes use it — signup
 * and login — and `authApi` already puts `deviceId`, `deviceName` and
 * `platform` in the body of both. Logout needs none of it: it ends the session
 * named by the token's own `sid` claim.
 *
 * So the headers were redundant everywhere, and on web they were actively
 * harmful. A custom request header triggers a CORS preflight, and the
 * backend's `allowedHeaders` list does not include them — so the browser
 * rejected the response and every login failed with
 * "Request header field x-device-id is not allowed by
 * Access-Control-Allow-Headers". Native has no preflight, which is why the
 * device build never showed it.
 *
 * Dropping them fixes the browser without touching the backend and without
 * losing anything: the same values still travel, in the body, where the server
 * prefers them anyway.
 */
apiClient.interceptors.request.use(config => {
  const token = tokenStore.getAccessToken();
  if (token) {
    config.headers.set('Authorization', `Bearer ${token}`);
  }

  return config;
});

// ---------------------------------------------------------------------------
// The refresh lock.
//
// A screen typically fires several requests at once. When the access token has
// expired they all come back 401 together, and each one wants a new token. The
// backend rotates the refresh token on every use and invalidates the old one,
// so a second concurrent refresh would be spending a token the first has
// already replaced: it fails, and — because a failed refresh signs the user
// out — it would sign out a session that had just been renewed successfully.
//
// So only the first 401 performs a refresh. Everything arriving while that is
// in flight awaits the same promise and then retries with whatever it produced.
// ---------------------------------------------------------------------------

let refreshInFlight: Promise<string | null> | null = null;

/**
 * Spends the stored refresh token for a new pair.
 *
 * @returns the new access token, or null when the session is unrecoverable.
 */
const performRefresh = async (): Promise<string | null> => {
  const refreshToken = tokenStore.getRefreshToken();

  if (!refreshToken) {
    return null;
  }

  try {
    const response = await refreshClient.post<ApiSuccess<AuthSession>>(
      '/auth/refresh-token',
      { refreshToken },
    );

    const session = response.data?.data;

    // A 200 whose body is not the expected envelope is a failure, not a
    // success with missing fields — storing undefined here would leave the app
    // "signed in" with no usable token.
    if (!session?.token || !session?.refreshToken) {
      return null;
    }

    await tokenStore.set(session.token, session.refreshToken);
    return session.token;
  } catch {
    // Unknown, spent, revoked or expired — the backend answers identically for
    // all of them on purpose. Either way there is no way back without a
    // password.
    return null;
  }
};

/** Single-flight wrapper: concurrent callers share one refresh. */
const refreshAccessToken = (): Promise<string | null> => {
  if (!refreshInFlight) {
    refreshInFlight = performRefresh().finally(() => {
      // Cleared only once the promise has settled, so the next expiry — which
      // may be days later — starts a fresh attempt rather than reusing this
      // one's resolved value.
      refreshInFlight = null;
    });
  }

  return refreshInFlight;
};

/**
 * Tears down the session after a refresh that cannot be recovered.
 *
 * Clearing comes first: the listener navigates to Login, and Login must never
 * be reachable with a stale token still in storage.
 */
const endSession = async (): Promise<void> => {
  await tokenStore.clear();
  tokenStore.notifySessionExpired();
};

// ---------------------------------------------------------------------------
// Response: renew once on 401, then retry the original request.
// ---------------------------------------------------------------------------

apiClient.interceptors.response.use(
  response => response,
  async (error: AxiosError) => {
    const config = error.config as RetryableConfig | undefined;
    const status = error.response?.status;

    if (status !== 401 || !config) {
      return Promise.reject(error);
    }

    const url = config.url ?? '';
    if (REFRESH_EXEMPT.some(path => url.includes(path))) {
      return Promise.reject(error);
    }

    // Already retried once. A second 401 on the same request means the new
    // token is not the problem, so retrying again would loop forever.
    if (config._genieRetry) {
      await endSession();
      return Promise.reject(error);
    }

    // Nothing to refresh with: the user was never signed in, or was signed out
    // while this request was in flight.
    if (!tokenStore.getRefreshToken()) {
      await endSession();
      return Promise.reject(error);
    }

    const newToken = await refreshAccessToken();

    if (!newToken) {
      await endSession();
      return Promise.reject(error);
    }

    config._genieRetry = true;
    config.headers.set('Authorization', `Bearer ${newToken}`);

    return apiClient(config);
  },
);

/**
 * Unwraps the backend's success envelope.
 *
 * Every successful response is `{success, message, data}` and every caller
 * wants `data`. Doing it here means no screen reaches into `.data.data`, which
 * is the mistake that silently yields undefined.
 */
export const unwrap = <T>(response: { data: ApiSuccess<T> }): T =>
  response.data.data;
