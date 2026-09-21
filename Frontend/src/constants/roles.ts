import { SIGNUP_ROLES } from '../types/auth';
import type { SignupRole } from '../types/auth';

export interface RoleOption {
  value: SignupRole;
  label: string;
  description: string;
}

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

export const ROLE_OPTIONS: readonly RoleOption[] = SIGNUP_ROLES.map(value => ({
  value,
  ...ROLE_DETAILS[value],
}));

export const DEFAULT_ROLE: SignupRole = 'client';

export const roleLabel = (value: SignupRole): string =>
  ROLE_DETAILS[value]?.label ?? value;
