/**
 * Client-side form validation.
 *
 * Every rule here mirrors one the backend enforces in
 * backend/src/validations/authValidation.js. It exists to spare the user a
 * round trip, never to replace the server's check — the server remains the
 * authority, and a rule that disagreed with it would reject input the backend
 * would have accepted.
 */

/** Matches the backend's `isEmail`, loosely enough not to reject valid addresses. */
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

/** The backend's exact regex: ten digits, first one 6-9. */
const MOBILE_PATTERN = /^[6-9]\d{9}$/;

/** Backend minimum. Longer is better, but rejecting here what the server
 *  accepts would be this layer overruling it. */
const PASSWORD_MIN_LENGTH = 6;

/** Backend minimum for fullName. */
const NAME_MIN_LENGTH = 3;

export const validateFullName = (value: string): string | undefined => {
  const trimmed = value.trim();
  if (!trimmed) {
    return 'Full name is required';
  }
  if (trimmed.length < NAME_MIN_LENGTH) {
    return `Full name must be at least ${NAME_MIN_LENGTH} characters`;
  }
  return undefined;
};

export const validateEmail = (value: string): string | undefined => {
  const trimmed = value.trim();
  if (!trimmed) {
    return 'Email is required';
  }
  if (!EMAIL_PATTERN.test(trimmed)) {
    return 'Enter a valid email address';
  }
  return undefined;
};

export const validateMobile = (value: string): string | undefined => {
  const trimmed = value.trim();
  if (!trimmed) {
    return 'Mobile number is required';
  }
  if (!MOBILE_PATTERN.test(trimmed)) {
    return 'Enter a valid 10-digit mobile number';
  }
  return undefined;
};

export const validatePassword = (value: string): string | undefined => {
  if (!value) {
    return 'Password is required';
  }
  if (value.length < PASSWORD_MIN_LENGTH) {
    return `Password must be at least ${PASSWORD_MIN_LENGTH} characters`;
  }
  return undefined;
};

/** Login only checks that a password was typed — length is the server's call. */
export const validateLoginPassword = (value: string): string | undefined =>
  value ? undefined : 'Password is required';

export const validateConfirmPassword = (
  password: string,
  confirmPassword: string,
): string | undefined => {
  if (!confirmPassword) {
    return 'Please confirm your password';
  }
  if (password !== confirmPassword) {
    return 'Passwords do not match';
  }
  return undefined;
};

/** The six-digit code sent by forgot-password. */
export const validateResetCode = (value: string): string | undefined => {
  const trimmed = value.trim();
  if (!trimmed) {
    return 'Reset code is required';
  }
  if (!/^\d{6}$/.test(trimmed)) {
    return 'Enter the 6-digit code from your email';
  }
  return undefined;
};

/**
 * Drops the undefined entries, leaving only real errors.
 *
 * Partial rather than a full Record: a screen that validates a subset of its
 * fields — the first step of the reset flow checks only the address — passes
 * only those, and requiring every key would force it to spell out `undefined`
 * for the rest.
 */
export const collectErrors = <K extends string>(
  candidates: Partial<Record<K, string | undefined>>,
): Partial<Record<K, string>> => {
  const errors: Partial<Record<K, string>> = {};
  (Object.keys(candidates) as K[]).forEach(key => {
    const message = candidates[key];
    if (message) {
      errors[key] = message;
    }
  });
  return errors;
};
