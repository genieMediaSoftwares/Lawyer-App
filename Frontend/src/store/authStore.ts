import { create } from 'zustand';

import { authApi } from '../api/authApi';
import { tokenStore } from '../api/tokenStore';
import { queryClient } from '../api/queryClient';
import { toAppError } from '../utils/errors';
import type { AuthUser, SignupRole } from '../types/auth';

/**
 * Authentication state, and the only thing navigation switches on.
 *
 * `status` is deliberately a three-way value rather than a boolean. The app
 * starts in "restoring" — it does not yet know whether a stored session is
 * valid — and treating that as "unauthenticated" is what makes an app flash
 * the Login screen before dropping a returning user into the home screen.
 */

export type AuthStatus = 'restoring' | 'authenticated' | 'unauthenticated';

interface AuthState {
  status: AuthStatus;
  user: AuthUser | null;

  /**
   * Reads the persisted session and verifies it against the backend.
   * Called once, by the splash screen.
   */
  restore: () => Promise<void>;

  login: (email: string, password: string) => Promise<void>;

  signup: (input: {
    fullName: string;
    email: string;
    mobile: string;
    password: string;
    role: SignupRole;
  }) => Promise<void>;

  logout: () => Promise<void>;

  /** Called by the network layer when a refresh has failed for good. */
  handleSessionExpired: () => void;
}

export const useAuthStore = create<AuthState>((set, get) => ({
  status: 'restoring',
  user: null,

  async restore() {
    const { accessToken, refreshToken } = await tokenStore.hydrate();

    // No credentials at all — a first launch, or a clean sign-out.
    if (!accessToken && !refreshToken) {
      set({ status: 'unauthenticated', user: null });
      return;
    }

    try {
      // The stored token is only a claim. This is the check: the backend
      // verifies the signature, confirms the session row is still live, and
      // returns the account. If the access token has expired, the interceptor
      // refreshes and retries transparently — which is exactly the behaviour a
      // returning user needs.
      const profile = await authApi.getProfile();

      set({
        status: 'authenticated',
        // The profile endpoint returns the raw document, so the identifier
        // arrives as `_id`. Mapped here so the rest of the app only ever sees
        // the AuthUser shape.
        user: {
          id: profile._id,
          fullName: profile.fullName,
          email: profile.email,
          mobile: profile.mobile,
          role: profile.role,
          profileImage: profile.profileImage,
          location: profile.location,
        },
      });
    } catch (error) {
      const info = toAppError(error);

      // A network failure is not a signed-out user. Clearing the tokens here
      // would sign out anyone who opened the app on a train, and they would
      // have to type a password to get back in. The session is left intact and
      // the user is sent to Login, where a retry costs nothing; the stored
      // tokens are still there for the next launch.
      if (!info.isNetworkError) {
        await tokenStore.clear();
      }

      set({ status: 'unauthenticated', user: null });
    }
  },

  async login(email, password) {
    const session = await authApi.login({ email, password });

    await tokenStore.set(session.token, session.refreshToken);
    set({ status: 'authenticated', user: session.user });
  },

  async signup(input) {
    // Signup opens a session server-side and returns the same payload login
    // does, so the account is signed in from here without a second request.
    const session = await authApi.signup(input);

    await tokenStore.set(session.token, session.refreshToken);
    set({ status: 'authenticated', user: session.user });
  },

  async logout() {
    try {
      // Reaching the server is what actually ends the session. Without it the
      // row stays live and the token keeps being accepted.
      await authApi.logout();
    } catch {
      // The user asked to be signed out, so they are signed out. A failed call
      // leaves a session row the backend will expire on its own; refusing to
      // clear local state would strand them on a screen they wanted to leave.
    } finally {
      await tokenStore.clear();
      queryClient.clear();
      set({ status: 'unauthenticated', user: null });
    }
  },

  handleSessionExpired() {
    // Tokens have already been cleared by the interceptor before this fires.
    queryClient.clear();
    if (get().status !== 'unauthenticated') {
      set({ status: 'unauthenticated', user: null });
    }
  },
}));

/**
 * Connects the network layer's session-expired signal to the store.
 *
 * Installed once at app start. The indirection is what keeps apiClient from
 * importing the store, which would be a require cycle.
 */
export const bindSessionExpiryHandler = (): (() => void) =>
  tokenStore.onSessionExpired(() => {
    useAuthStore.getState().handleSessionExpired();
  });
