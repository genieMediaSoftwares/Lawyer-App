import axios from 'axios';
import type {
  AxiosError,
  AxiosInstance,
  InternalAxiosRequestConfig,
} from 'axios';

import { env } from '../config/env';
import { tokenStore } from './tokenStore';
import type { ApiSuccess } from '../types/api';
import type { AuthSession } from '../types/auth';

const REFRESH_EXEMPT = [
  '/auth/refresh-token',
  '/auth/login',
  '/auth/signup',
  '/auth/forgot-password',
  '/auth/reset-password',
];

interface RetryableConfig extends InternalAxiosRequestConfig {
  _genieRetry?: boolean;
}

export const apiClient: AxiosInstance = axios.create({
  baseURL: env.apiBaseUrl,
  timeout: env.apiTimeoutMs,
  headers: { 'Content-Type': 'application/json' },
});

const refreshClient: AxiosInstance = axios.create({
  baseURL: env.apiBaseUrl,
  timeout: env.apiTimeoutMs,
  headers: { 'Content-Type': 'application/json' },
});

apiClient.interceptors.request.use(config => {
  const token = tokenStore.getAccessToken();
  if (token) {
    config.headers.set('Authorization', `Bearer ${token}`);
  }

  return config;
});

let refreshInFlight: Promise<string | null> | null = null;

const performRefresh = async (): Promise<string | null> => {
  const refreshToken = tokenStore.getRefreshToken();

  if (!refreshToken) {
    return null;
  }

  try {
    const response = await refreshClient.post<ApiSuccess<AuthSession>>(
      '/auth/refresh-token',
      { refreshToken },
    );

    const session = response.data?.data;

    if (!session?.token || !session?.refreshToken) {
      return null;
    }

    await tokenStore.set(session.token, session.refreshToken);
    return session.token;
  } catch {
    return null;
  }
};

const refreshAccessToken = (): Promise<string | null> => {
  if (!refreshInFlight) {
    refreshInFlight = performRefresh().finally(() => {
      refreshInFlight = null;
    });
  }

  return refreshInFlight;
};

const endSession = async (): Promise<void> => {
  await tokenStore.clear();
  tokenStore.notifySessionExpired();
};

apiClient.interceptors.response.use(
  response => response,
  async (error: AxiosError) => {
    const config = error.config as RetryableConfig | undefined;
    const status = error.response?.status;

    if (status !== 401 || !config) {
      return Promise.reject(error);
    }

    const url = config.url ?? '';
    if (REFRESH_EXEMPT.some(path => url.includes(path))) {
      return Promise.reject(error);
    }

    if (config._genieRetry) {
      await endSession();
      return Promise.reject(error);
    }

    if (!tokenStore.getRefreshToken()) {
      await endSession();
      return Promise.reject(error);
    }

    const newToken = await refreshAccessToken();

    if (!newToken) {
      await endSession();
      return Promise.reject(error);
    }

    config._genieRetry = true;
    config.headers.set('Authorization', `Bearer ${newToken}`);

    return apiClient(config);
  },
);

export const unwrap = <T>(response: { data: ApiSuccess<T> }): T =>
  response.data.data;
