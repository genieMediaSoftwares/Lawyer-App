/**
 * Authentication contracts, verified against the running backend.
 *
 * Request bodies match backend/src/validations/authValidation.js exactly.
 * Response bodies match what POST /api/auth/login actually returned.
 */

/** The roles the backend accepts at signup. */
export const SIGNUP_ROLES = ['client', 'lawyer'] as const;
export type SignupRole = (typeof SIGNUP_ROLES)[number];

/**
 * Roles the User schema allows. "admin" exists in the schema but signup
 * validation rejects it, so it can only arrive on an account made elsewhere.
 */
export type UserRole = SignupRole | 'admin';

/**
 * The user object returned by login, signup and refresh-token.
 *
 * This is `publicUser()` in backend/src/services/auth/authService.js: an
 * allowlisted projection that never includes the password hash.
 */
export interface AuthUser {
  id: string;
  fullName: string;
  email: string;
  mobile: string;
  role: UserRole;
  profileImage: string;
  location: string;
}

/**
 * The user object returned by GET /api/auth/profile.
 *
 * Deliberately a separate type. That endpoint returns the raw Mongoose
 * document rather than `publicUser()`, so the identifier arrives as `_id` and
 * several schema fields come along with it. Treating the two as one type is
 * how an `id` ends up undefined at runtime.
 */
export interface ProfileUser {
  _id: string;
  fullName: string;
  email: string;
  mobile: string;
  role: UserRole;
  profileImage: string;
  location: string;
  dob: string;
  gender: string;
  languages: string[];
  isVerified: boolean;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

/** The `data` payload of login, signup and refresh-token — identical for all three. */
export interface AuthSession {
  /** The access token. Named `token`, not `accessToken`. */
  token: string;
  refreshToken: string;
  /** Access-token lifetime in seconds. */
  expiresIn: number;
  user: AuthUser;
}

/**
 * Device fields the backend reads off the body (or the X-Device-* headers) to
 * label and scope a session. Signing in again from the same `deviceId`
 * replaces that device's session instead of opening a second one.
 */
export interface DeviceContext {
  deviceId: string;
  deviceName: string;
  platform: string;
}

export interface LoginRequest extends DeviceContext {
  email: string;
  password: string;
}

export interface SignupRequest extends DeviceContext {
  fullName: string;
  email: string;
  /** Ten digits starting 6-9, per the backend's own regex. */
  mobile: string;
  password: string;
  role: SignupRole;
}

export interface RefreshRequest {
  refreshToken: string;
}

export interface ForgotPasswordRequest {
  email: string;
}

export interface ResetPasswordRequest {
  email: string;
  /** The six-digit code emailed by forgot-password. */
  token: string;
  newPassword: string;
}

/** What /auth/logout-all returns in `data`. */
export interface LogoutAllResult {
  sessionsRevoked: number;
}
