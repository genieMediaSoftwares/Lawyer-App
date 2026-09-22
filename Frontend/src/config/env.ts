import {
  API_BASE_URL,
  API_TIMEOUT_MS,
  SUPPORT_EMAIL,
  SUPPORT_PHONE,
  AI_UPLOAD_MAX_MB,
  AI_OPTIMIZE_MAX_MB,
} from '@env';
import { version as packageVersion } from '../../package.json';

const DEFAULT_TIMEOUT_MS = 20000;

// Public support contact. Not secrets; SUPPORT_EMAIL / SUPPORT_PHONE override them.
const DEFAULT_SUPPORT_EMAIL = 'kkdigitalteamwork@gmail.com';
const DEFAULT_SUPPORT_PHONE = '9966888428';

const DEFAULT_AI_UPLOAD_MAX_MB = 3;
const DEFAULT_AI_OPTIMIZE_MAX_MB = 20;

const stripTrailingSlash = (value: string): string =>
  value.endsWith('/') ? value.slice(0, -1) : value;

const readBaseUrl = (): string => {
  const configured = API_BASE_URL?.trim();

  if (!configured) {
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

const readOptional = (value: string | undefined): string | null =>
  value?.trim() ? value.trim() : null;

const readMegabytes = (value: string | undefined): number | null => {
  const parsed = Number.parseFloat(value ?? '');
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
};

export const env = {
  apiBaseUrl: readBaseUrl(),
  apiTimeoutMs: readTimeout(),
  supportEmail: readOptional(SUPPORT_EMAIL) ?? DEFAULT_SUPPORT_EMAIL,
  supportPhone: readOptional(SUPPORT_PHONE) ?? DEFAULT_SUPPORT_PHONE,
  // AI Smart Case Assistant: largest document accepted after optimization, and
  // largest original the server will receive to optimize.
  aiUploadMaxMb: readMegabytes(AI_UPLOAD_MAX_MB) ?? DEFAULT_AI_UPLOAD_MAX_MB,
  aiOptimizeMaxMb: readMegabytes(AI_OPTIMIZE_MAX_MB) ?? DEFAULT_AI_OPTIMIZE_MAX_MB,
  appVersion: packageVersion,
};
