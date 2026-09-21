import { apiClient, unwrap } from './apiClient';
import { getDeviceContext } from '../services/device';
import type { ApiSuccess } from '../types/api';
import type {
  AuthSession,
  LogoutAllResult,
  ProfileUser,
  SignupRole,
} from '../types/auth';

/**
 * The authentication endpoints the Genie Law backend actually exposes.
 *
 * Every path here was read from backend/src/routes/authRoutes.js and exercised
 * against the running server. Nothing is added speculatively: an endpoint that
 * does not exist on the backend does not get a function here.
 *
 * Notably absent, because the backend has no such route: Google sign-in,
 * mobile OTP, and email verification. See README.md.
 */

export const authApi = {
  /**
   * POST /auth/signup
   *
   * Registers the account and signs it in — the backend opens a session and
   * returns the same payload login does, so there is no second round trip.
   * 409 when the email or mobile is taken; 400 with an `errors` array when a
   * field fails validation.
   */
  async signup(input: {
    fullName: string;
    email: string;
    mobile: string;
    password: string;
    role: SignupRole;
  }): Promise<AuthSession> {
    const device = await getDeviceContext();

    const response = await apiClient.post<ApiSuccess<AuthSession>>(
      '/auth/signup',
      { ...input, ...device },
    );

    return unwrap(response);
  },

  /**
   * POST /auth/login
   *
   * 401 with code INVALID_CREDENTIALS for both a wrong password and an unknown
   * address — the backend does not distinguish them, so neither may this.
   */
  async login(input: { email: string; password: string }): Promise<AuthSession> {
    const device = await getDeviceContext();

    const response = await apiClient.post<ApiSuccess<AuthSession>>(
      '/auth/login',
      { ...input, ...device },
    );

    return unwrap(response);
  },

  /**
   * GET /auth/profile
   *
   * Returns the raw user document, so the identifier is `_id` here and `id` in
   * the login payload. Hence the separate ProfileUser type.
   */
  async getProfile(): Promise<ProfileUser> {
    const response = await apiClient.get<ApiSuccess<ProfileUser>>(
      '/auth/profile',
    );
    return unwrap(response);
  },

  /**
   * POST /auth/logout
   *
   * Ends only the session this device holds. The server call matters: without
   * it the session row stays live for its full lifetime and the token keeps
   * working.
   */
  async logout(): Promise<void> {
    await apiClient.post<ApiSuccess<null>>('/auth/logout');
  },

  /** POST /auth/logout-all — ends every session on the account. */
  async logoutAllDevices(): Promise<LogoutAllResult> {
    const response = await apiClient.post<ApiSuccess<LogoutAllResult>>(
      '/auth/logout-all',
    );
    return unwrap(response);
  },

  /**
   * POST /auth/forgot-password
   *
   * Always answers 200, whether or not the address is registered — the backend
   * refuses to be a user-enumeration oracle, so the UI must not imply that a
   * success means the account exists.
   */
  async forgotPassword(email: string): Promise<void> {
    await apiClient.post<ApiSuccess<null>>('/auth/forgot-password', { email });
  },

  /**
   * POST /auth/reset-password
   *
   * `token` is the six-digit code emailed by forgot-password. 400 when it is
   * wrong or older than fifteen minutes.
   */
  async resetPassword(input: {
    email: string;
    token: string;
    newPassword: string;
  }): Promise<void> {
    await apiClient.post<ApiSuccess<null>>('/auth/reset-password', input);
  },

  /**
   * POST /auth/profile/image
   * Uploads profile avatar photo using FormData
   */
  async uploadProfileImage(file: File | { uri: string; name: string; type: string }): Promise<ProfileUser> {
    const formData = new FormData();
    if (typeof File !== 'undefined' && file instanceof File) {
      formData.append('profileImage', file);
    } else {
      formData.append('profileImage', file as any);
    }

    const response = await apiClient.post<ApiSuccess<ProfileUser>>(
      '/auth/profile/image',
      formData,
      {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      },
    );
    return unwrap(response);
  },

  /**
   * POST /auth/change-password
   */
  async changePassword(input: {
    currentPassword?: string;
    newPassword?: string;
    oldPassword?: string;
  }): Promise<void> {
    await apiClient.post<ApiSuccess<null>>('/auth/change-password', input);
  },

  /**
   * POST /auth/delete-account
   */
  async deleteAccount(password: string): Promise<void> {
    await apiClient.post<ApiSuccess<null>>('/auth/delete-account', { password });
  },
};
