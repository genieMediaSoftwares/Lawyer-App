import { Platform } from 'react-native';

import { secureStorage } from './secureStorage';
import type { DeviceContext } from '../types/auth';

/**
 * The installation's identity, as the backend's session layer understands it.
 *
 * `deviceId` is generated once, kept in secure storage, and survives app
 * restarts, updates and sign-outs. The backend scopes session replacement to
 * it (sessionService.revokeSessionsForDevice), so a stable value is what stops
 * every restart from leaving an orphaned session behind — and what keeps this
 * device from ever revoking another one's.
 *
 * It is a random label, never a hardware identifier: nothing here identifies
 * the person, and nothing survives an uninstall.
 */

const randomHex = (bytes: number): string => {
  let out = '';
  for (let i = 0; i < bytes; i += 1) {
    out += Math.floor(Math.random() * 256)
      .toString(16)
      .padStart(2, '0');
  }
  return out;
};

/**
 * Timestamp plus 16 random bytes. The random half alone makes a collision
 * vanishingly unlikely; the timestamp means two installations would also have
 * to be created in the same millisecond for one to be possible at all.
 */
const generateDeviceId = (): string =>
  `${Platform.OS}-${Date.now().toString(36)}-${randomHex(16)}`;

let cached: string | null = null;

export const getDeviceId = async (): Promise<string> => {
  if (cached) {
    return cached;
  }

  const stored = await secureStorage.getDeviceId();
  if (stored) {
    cached = stored;
    return stored;
  }

  const created = generateDeviceId();
  await secureStorage.saveDeviceId(created);
  cached = created;
  return created;
};

/** The three device fields login and signup send with every request. */
export const getDeviceContext = async (): Promise<DeviceContext> => ({
  deviceId: await getDeviceId(),
  // A model name would be a nicer label, but reading one costs a native
  // dependency for a field the backend only ever displays. The platform and
  // version are enough to tell one device from another in a session list.
  deviceName: `${Platform.OS} ${String(Platform.Version)}`,
  platform: Platform.OS,
});
