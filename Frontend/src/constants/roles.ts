import { SIGNUP_ROLES } from '../types/auth';
import type { SignupRole } from '../types/auth';

/**
 * The roles a person may register as.
 *
 * The list is the backend's, not this app's: signup validation in
 * backend/src/validations/authValidation.js accepts exactly `client` and
 * `lawyer`, and authService.register coerces anything else to `client`. The
 * User schema also has `admin`, but signup rejects it — an administrator is
 * seeded server-side, never self-registered — so it is deliberately not
 * offered here.
 *
 * Adding an option to this list without adding it to the backend's validator
 * produces a 400 on submit. The labels below are presentation only.
 */

export interface RoleOption {
  value: SignupRole;
  label: string;
  description: string;
}

/**
 * Presentation for each role.
 *
 * Typed as a full Record over the backend's role union, so a role added to
 * SIGNUP_ROLES that has no entry here stops the build rather than rendering an
 * option with a blank label.
 */
const ROLE_DETAILS: Record<SignupRole, Omit<RoleOption, 'value'>> = {
  client: {
    label: 'Client',
    description: 'Looking for legal help and advice',
  },
  lawyer: {
    label: 'Lawyer',
    description: 'Practising advocate offering services',
  },
};

/** Built from the backend's own list, so the order and the membership match it. */
export const ROLE_OPTIONS: readonly RoleOption[] = SIGNUP_ROLES.map(value => ({
  value,
  ...ROLE_DETAILS[value],
}));

/** The role a new signup form starts on. */
export const DEFAULT_ROLE: SignupRole = 'client';

export const roleLabel = (value: SignupRole): string =>
  ROLE_DETAILS[value]?.label ?? value;
