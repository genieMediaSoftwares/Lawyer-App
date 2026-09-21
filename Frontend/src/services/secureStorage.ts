import * as Keychain from 'react-native-keychain';

/**
 * Credential storage, backed by the Keychain on iOS and the Android Keystore
 * (through EncryptedSharedPreferences) on Android.
 *
 * Tokens never touch AsyncStorage, which is a plaintext file on both
 * platforms. Passwords are never written here or anywhere else — they are used
 * for the one request that needs them and then dropped.
 *
 * Each value lives under its own `service`, which is what lets them be read,
 * rotated and cleared independently.
 */

const SERVICE = {
  accessToken: 'com.genielaw.auth.accessToken',
  refreshToken: 'com.genielaw.auth.refreshToken',
  deviceId: 'com.genielaw.device.id',
} as const;

/**
 * Keychain stores a username/password pair; only the password half is used.
 * The username half has to be non-empty for the write to succeed on Android,
 * so it carries the key name.
 */
const write = async (service: string, value: string): Promise<void> => {
  await Keychain.setGenericPassword(service, value, {
    service,
    accessible: Keychain.ACCESSIBLE.AFTER_FIRST_UNLOCK_THIS_DEVICE_ONLY,
  });
};

const read = async (service: string): Promise<string | null> => {
  try {
    const result = await Keychain.getGenericPassword({ service });
    return result === false ? null : result.password;
  } catch {
    // A corrupt or inaccessible entry — a restored backup on a new device,
    // for instance — must read as "no credential" rather than crash the
    // splash screen. The caller then routes to Login, which is correct.
    return null;
  }
};

const remove = async (service: string): Promise<void> => {
  try {
    await Keychain.resetGenericPassword({ service });
  } catch {
    // Clearing is best-effort by design: it runs on the path that signs a user
    // out after a failed refresh, and that path must always reach Login.
  }
};

export const secureStorage = {
  async saveTokens(accessToken: string, refreshToken: string): Promise<void> {
    await Promise.all([
      write(SERVICE.accessToken, accessToken),
      write(SERVICE.refreshToken, refreshToken),
    ]);
  },

  getAccessToken: (): Promise<string | null> => read(SERVICE.accessToken),

  getRefreshToken: (): Promise<string | null> => read(SERVICE.refreshToken),

  /**
   * Drops both tokens. The device id deliberately survives: it identifies the
   * installation, not the person, and keeping it is what lets the backend
   * recognise the next sign-in as the same device and replace that device's
   * session rather than stacking another one onto the account.
   */
  async clearTokens(): Promise<void> {
    await Promise.all([
      remove(SERVICE.accessToken),
      remove(SERVICE.refreshToken),
    ]);
  },

  getDeviceId: (): Promise<string | null> => read(SERVICE.deviceId),

  saveDeviceId: (deviceId: string): Promise<void> =>
    write(SERVICE.deviceId, deviceId),
};
