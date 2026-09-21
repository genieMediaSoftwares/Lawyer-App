/**
 * The browser implementation of the credential store.
 *
 * Metro and Vite both resolve `.web.ts` ahead of `.ts`, so importing
 * `./secureStorage` picks this file on web and the Keychain-backed one on
 * device. Nothing else in the app changes, and `react-native-keychain` — which
 * has no browser build — is never pulled into the web bundle.
 *
 * This is a real store: it genuinely persists and genuinely reads back. It is
 * not a stand-in and it returns nothing the backend did not issue.
 *
 * It is, however, materially less safe than the native one. A browser has no
 * Keychain and no Keystore; `localStorage` is plain text, readable by any
 * script running on the origin, so an XSS bug hands over both tokens. The
 * native targets are the product. **The web target is a development preview —
 * for seeing the UI and exercising the real API without an emulator — and is
 * not a surface to ship to users.** Shipping it would mean moving the refresh
 * token to an httpOnly cookie, which is a backend change.
 */

const KEY = {
  accessToken: 'genielaw.auth.accessToken',
  refreshToken: 'genielaw.auth.refreshToken',
  deviceId: 'genielaw.device.id',
} as const;

/**
 * Every access is guarded. `localStorage` throws outright in a sandboxed
 * iframe, in Safari's private mode once the quota is reached, and whenever the
 * user has blocked site data — and a throw here would take down the splash
 * screen rather than simply meaning "no credential".
 */
const read = (key: string): string | null => {
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
};

const write = (key: string, value: string): void => {
  try {
    window.localStorage.setItem(key, value);
  } catch {
    // Storage unavailable. The session then lasts as long as the tab, which is
    // a degraded experience rather than a broken one.
  }
};

const remove = (key: string): void => {
  try {
    window.localStorage.removeItem(key);
  } catch {
    // Best-effort, exactly as on native: this runs on the path that signs a
    // user out after a failed refresh, and that path must always reach Login.
  }
};

export const secureStorage = {
  async saveTokens(accessToken: string, refreshToken: string): Promise<void> {
    write(KEY.accessToken, accessToken);
    write(KEY.refreshToken, refreshToken);
  },

  async getAccessToken(): Promise<string | null> {
    return read(KEY.accessToken);
  },

  async getRefreshToken(): Promise<string | null> {
    return read(KEY.refreshToken);
  },

  /** Drops both tokens. The device id survives, as it does on native. */
  async clearTokens(): Promise<void> {
    remove(KEY.accessToken);
    remove(KEY.refreshToken);
  },

  async getDeviceId(): Promise<string | null> {
    return read(KEY.deviceId);
  },

  async saveDeviceId(deviceId: string): Promise<void> {
    write(KEY.deviceId, deviceId);
  },
};
