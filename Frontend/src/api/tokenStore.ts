import { secureStorage } from '../services/secureStorage';

/**
 * The live token pair, mirrored in memory over secure storage.
 *
 * The mirror exists because the request interceptor runs on every call and a
 * Keychain read is a native round trip — doing one per request is both slow
 * and, on some Android configurations, enough to surface a biometric prompt.
 * Secure storage stays the durable copy; this is the hot path's view of it.
 *
 * `onSessionExpired` is how the network layer tells the app that the session
 * is unrecoverable. The auth store installs a listener at startup; without it
 * the interceptor would have to import the store and the navigator, which is
 * the usual route to a require cycle.
 */

interface Tokens {
  accessToken: string | null;
  refreshToken: string | null;
}

let memory: Tokens = { accessToken: null, refreshToken: null };
let sessionExpiredListener: (() => void) | null = null;

export const tokenStore = {
  /** Loads the persisted pair into memory. Called once, by the splash screen. */
  async hydrate(): Promise<Tokens> {
    const [accessToken, refreshToken] = await Promise.all([
      secureStorage.getAccessToken(),
      secureStorage.getRefreshToken(),
    ]);
    memory = { accessToken, refreshToken };
    return memory;
  },

  getAccessToken: (): string | null => memory.accessToken,

  getRefreshToken: (): string | null => memory.refreshToken,

  /** Writes a new pair to memory and to secure storage together. */
  async set(accessToken: string, refreshToken: string): Promise<void> {
    memory = { accessToken, refreshToken };
    await secureStorage.saveTokens(accessToken, refreshToken);
  },

  async clear(): Promise<void> {
    memory = { accessToken: null, refreshToken: null };
    await secureStorage.clearTokens();
  },

  /**
   * Registers the app's response to an unrecoverable session.
   *
   * @returns an unsubscribe function.
   */
  onSessionExpired(listener: () => void): () => void {
    sessionExpiredListener = listener;
    return () => {
      if (sessionExpiredListener === listener) {
        sessionExpiredListener = null;
      }
    };
  },

  /** Fired by the interceptor once a refresh has definitively failed. */
  notifySessionExpired(): void {
    sessionExpiredListener?.();
  },
};
