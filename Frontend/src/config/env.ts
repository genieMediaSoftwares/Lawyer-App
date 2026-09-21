import {
  API_BASE_URL,
  API_TIMEOUT_MS,
  SUPPORT_EMAIL,
  SUPPORT_PHONE,
  AI_UPLOAD_MAX_MB,
} from '@env';
import { version as packageVersion } from '../../package.json';

/**
 * The single place the backend address enters the app.
 *
 * Nothing else may hardcode a URL: every request is built from `apiBaseUrl`,
 * so pointing the app at a different environment is one line in .env and a
 * rebuild.
 */

const DEFAULT_TIMEOUT_MS = 20000;

const stripTrailingSlash = (value: string): string =>
  value.endsWith('/') ? value.slice(0, -1) : value;

const readBaseUrl = (): string => {
  const configured = API_BASE_URL?.trim();

  if (!configured) {
    // A missing base URL cannot be recovered from at runtime, and failing here
    // names the cause once rather than producing a confusing "Network Error"
    // on every screen.
    throw new Error(
      'API_BASE_URL is not set. Copy .env.example to .env and set it to the ' +
        'address of the Genie Law backend, then restart Metro with --reset-cache.',
    );
  }

  return stripTrailingSlash(configured);
};

const readTimeout = (): number => {
  const parsed = Number.parseInt(API_TIMEOUT_MS ?? '', 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : DEFAULT_TIMEOUT_MS;
};

/** Unset or blank means "not configured", which callers must handle. */
const readOptional = (value: string | undefined): string | null =>
  value?.trim() ? value.trim() : null;

/** A positive number of megabytes, or null when unset or not a number. */
const readMegabytes = (value: string | undefined): number | null => {
  const parsed = Number.parseFloat(value ?? '');
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
};

export const env = {
  apiBaseUrl: readBaseUrl(),
  apiTimeoutMs: readTimeout(),
  /**
   * Public support contact shown on About. Optional on purpose: there is no
   * authoritative address in the codebase (the app said support@genielaw.com,
   * the backend's own User-Agent says support@genielaw.app), so nothing is
   * shown until a real one is configured.
   */
  supportEmail: readOptional(SUPPORT_EMAIL),
  supportPhone: readOptional(SUPPORT_PHONE),
  /**
   * The most one AI upload (all documents plus the voice note, in one request)
   * may weigh, in MB. This is the *server's* request-size ceiling — nginx's
   * `client_max_body_size` — which is separate from the backend's own 10 MB
   * per-file limit and, as deployed, much lower. Null means "no ceiling beyond
   * the per-file limit".
   */
  aiUploadMaxMb: readMegabytes(AI_UPLOAD_MAX_MB),
  /** From package.json, which android/app/build.gradle also reads. */
  appVersion: packageVersion,
};
