import * as Keychain from 'react-native-keychain';

const SERVICE = {
  accessToken: 'com.genielaw.auth.accessToken',
  refreshToken: 'com.genielaw.auth.refreshToken',
  deviceId: 'com.genielaw.device.id',
} as const;

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
    return null;
  }
};

const remove = async (service: string): Promise<void> => {
  try {
    await Keychain.resetGenericPassword({ service });
  } catch {
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
