import { create } from 'zustand';

import { authApi } from '../api/authApi';
import { tokenStore } from '../api/tokenStore';
import { queryClient } from '../api/queryClient';
import { toAppError } from '../utils/errors';
import type { AuthUser, SignupRole } from '../types/auth';

export type AuthStatus = 'restoring' | 'authenticated' | 'unauthenticated';

interface AuthState {
  status: AuthStatus;
  user: AuthUser | null;

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

  handleSessionExpired: () => void;
}

export const useAuthStore = create<AuthState>((set, get) => ({
  status: 'restoring',
  user: null,

  async restore() {
    const { accessToken, refreshToken } = await tokenStore.hydrate();

    if (!accessToken && !refreshToken) {
      set({ status: 'unauthenticated', user: null });
      return;
    }

    try {
      const profile = await authApi.getProfile();

      set({
        status: 'authenticated',
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
    const session = await authApi.signup(input);

    await tokenStore.set(session.token, session.refreshToken);
    set({ status: 'authenticated', user: session.user });
  },

  async logout() {
    try {
      await authApi.logout();
    } catch {
    } finally {
      await tokenStore.clear();
      queryClient.clear();
      set({ status: 'unauthenticated', user: null });
    }
  },

  handleSessionExpired() {
    queryClient.clear();
    if (get().status !== 'unauthenticated') {
      set({ status: 'unauthenticated', user: null });
    }
  },
}));

export const bindSessionExpiryHandler = (): (() => void) =>
  tokenStore.onSessionExpired(() => {
    useAuthStore.getState().handleSessionExpired();
  });
