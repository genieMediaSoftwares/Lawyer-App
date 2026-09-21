import { env } from '../config/env';

/**
 * The API base minus its `/api` suffix — where `/uploads` is served from.
 * E.g., `https://lawyerappvizag.duckdns.org/api` -> `https://lawyerappvizag.duckdns.org`
 */
const fileOrigin = (): string => env.apiBaseUrl.replace(/\/api\/?$/i, '');

/**
 * Turns whatever the backend stored in a URL field into a valid, loadable URL.
 *
 * Handles:
 *   - `/uploads/profiles/file.jpg`
 *   - `uploads/profiles/file.jpg`
 *   - Full URLs containing outdated/stale hosts (e.g. `http://192.168.0.9:5000/uploads/...`)
 *   - External URLs (e.g. Google profile photos)
 *   - Data URIs
 *
 * Ensures clean single slashes without hardcoding any IP address in components.
 */
export const resolveFileUrl = (value?: string | null): string | null => {
  const raw = String(value ?? '').trim();

  if (!raw) {
    return null;
  }

  // Data URIs should be returned directly
  if (raw.startsWith('data:')) {
    return raw;
  }

  const origin = fileOrigin();

  // If the path contains `/uploads/` (regardless of old domain/IP or relative path)
  const uploadsIndex = raw.indexOf('/uploads/');
  if (uploadsIndex !== -1) {
    const uploadPath = raw.slice(uploadsIndex); // e.g. "/uploads/profiles/abc.jpg"
    return `${origin}${uploadPath}`;
  }

  if (raw.startsWith('uploads/')) {
    return `${origin}/${raw}`;
  }

  // If it is an external full URL (starts with http:// or https://) and does NOT point to /uploads/
  if (/^https?:\/\//i.test(raw)) {
    return raw.replace(/([^:])\/{2,}/g, '$1/');
  }

  // Relative paths
  const path = raw.startsWith('/') ? raw : `/${raw}`;
  return `${origin}${path}`;
};

/**
 * Centralized alias for upload/asset URL resolution.
 * All profile/document/uploaded images use this function.
 */
export const getUploadUrl = resolveFileUrl;

/**
 * Whether a URL points at the public profiles upload folder served without auth token.
 */
export const isPublicUpload = (value?: string | null): boolean =>
  /\/uploads\/profiles\//i.test(String(value ?? ''));

/**
 * A human-readable file size helper.
 */
export const formatFileSize = (size?: string | number | null): string => {
  if (size === null || size === undefined || size === '') {
    return '';
  }

  const asNumber = typeof size === 'number' ? size : Number(String(size).trim());

  if (!Number.isFinite(asNumber)) {
    return String(size);
  }

  if (asNumber < 1024) {
    return `${asNumber} B`;
  }
  if (asNumber < 1024 * 1024) {
    return `${(asNumber / 1024).toFixed(0)} KB`;
  }
  return `${(asNumber / (1024 * 1024)).toFixed(1)} MB`;
};
