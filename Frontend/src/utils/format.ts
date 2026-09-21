/**
 * Display formatting.
 *
 * Every function here returns an empty string for missing input rather than a
 * dash, "N/A" or today's date. A caller that gets "" renders its empty
 * treatment; a caller handed a fabricated fallback would render a lie.
 *
 * `Intl` is used directly — Hermes ships full ICU on both platforms, and the
 * browser has it natively, so no locale polyfill is needed.
 */

const parse = (value?: string | number | Date | null): Date | null => {
  if (value === null || value === undefined || value === '') {
    return null;
  }

  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
};

/** "12 Mar 2026" */
export const formatDate = (value?: string | number | Date | null): string => {
  const date = parse(value);
  if (!date) {
    return '';
  }

  return new Intl.DateTimeFormat('en-IN', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  }).format(date);
};

/** "12 Mar 2026, 4:30 pm" */
export const formatDateTime = (
  value?: string | number | Date | null,
): string => {
  const date = parse(value);
  if (!date) {
    return '';
  }

  return new Intl.DateTimeFormat('en-IN', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  }).format(date);
};

/**
 * "just now", "4h ago", "3d ago", then an absolute date.
 *
 * Relative time stops being useful past a week — "23d ago" makes a reader do
 * arithmetic — so beyond that it falls back to the real date.
 */
export const formatRelative = (
  value?: string | number | Date | null,
): string => {
  const date = parse(value);
  if (!date) {
    return '';
  }

  const seconds = Math.floor((Date.now() - date.getTime()) / 1000);

  // A clock skew between device and server can make a fresh record look like
  // it arrived from the future. Report that as "just now", not "-3m ago".
  if (seconds < 60) {
    return 'just now';
  }
  if (seconds < 3600) {
    return `${Math.floor(seconds / 60)}m ago`;
  }
  if (seconds < 86400) {
    return `${Math.floor(seconds / 3600)}h ago`;
  }
  if (seconds < 604800) {
    return `${Math.floor(seconds / 86400)}d ago`;
  }

  return formatDate(date);
};

/**
 * "₹1,500", or "" when there is no fee to show.
 *
 * Zero is treated as *unset*, not as free. A Lawyer document created by the
 * backend's auto-provisioning path starts with `consultationFee: 0`, and
 * rendering that as "₹0" advertises a free consultation the advocate never
 * offered. Same reasoning as formatRating: a zero from this backend means
 * "nobody has filled this in".
 */
export const formatFee = (value?: number | null): string => {
  if (typeof value !== 'number' || !Number.isFinite(value) || value <= 0) {
    return '';
  }

  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0,
  }).format(value);
};

/**
 * "4.6" — or "" when there is no rating yet.
 *
 * A zero from the server means *nobody has rated this advocate*, not that they
 * scored zero. Returning "" keeps those apart, and the UI shows "No ratings
 * yet" rather than a damning 0.0 (§15: do not invent lawyer statistics).
 */
export const formatRating = (value?: number | null): string => {
  if (typeof value !== 'number' || !Number.isFinite(value) || value <= 0) {
    return '';
  }
  return value.toFixed(1);
};

/** "8 years" / "1 year" / "" when unset. */
export const formatExperience = (years?: number | null): string => {
  if (typeof years !== 'number' || !Number.isFinite(years) || years <= 0) {
    return '';
  }
  return `${years} ${years === 1 ? 'year' : 'years'}`;
};

/** Trims to a word boundary and appends an ellipsis. */
export const truncate = (value: string, max: number): string => {
  const text = String(value || '').trim();
  if (text.length <= max) {
    return text;
  }

  const cut = text.slice(0, max);
  const lastSpace = cut.lastIndexOf(' ');
  return `${(lastSpace > max * 0.6 ? cut.slice(0, lastSpace) : cut).trimEnd()}…`;
};

export const formatFileSize = (bytes?: number | string | null): string => {
  if (typeof bytes === 'string') return bytes;
  if (typeof bytes !== 'number' || !Number.isFinite(bytes) || bytes <= 0) return '';
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
};
