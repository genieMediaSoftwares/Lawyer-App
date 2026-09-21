/**
 * Native-module stand-ins for the Jest environment.
 *
 * Jest runs in Node, where no TurboModule is registered, so every library that
 * calls `TurboModuleRegistry.getEnforcing()` at import time throws before a
 * test starts. Where a library ships its own Jest mock it is used as-is; the
 * two that do not get the smallest stub that satisfies their import surface.
 *
 * These stub *native bindings* only. They are not app data and are never
 * bundled into the app.
 */

jest.mock('react-native-reanimated', () => require('react-native-reanimated/mock'));
jest.mock('react-native-worklets', () => require('react-native-worklets/src/mock'));
jest.mock('react-native-safe-area-context', () =>
  require('react-native-safe-area-context/jest/mock').default,
);

jest.mock('react-native-keychain', () => ({
  ACCESSIBLE: {},
  SECURITY_LEVEL: {},
  STORAGE_TYPE: {},
  setGenericPassword: jest.fn(() => Promise.resolve(true)),
  getGenericPassword: jest.fn(() => Promise.resolve(false)),
  resetGenericPassword: jest.fn(() => Promise.resolve(true)),
}));

jest.mock('react-native-audio-recorder-player', () => ({
  __esModule: true,
  default: {
    startRecorder: jest.fn(),
    stopRecorder: jest.fn(),
    addRecordBackListener: jest.fn(),
    removeRecordBackListener: jest.fn(),
  },
  AudioEncoderAndroidType: { AAC: 3 },
  AudioSourceAndroidType: { MIC: 1 },
  OutputFormatAndroidType: { MPEG_4: 2 },
  AVEncoderAudioQualityIOSType: { HIGH: 96 },
}));
