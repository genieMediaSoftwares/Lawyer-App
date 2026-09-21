import { PermissionsAndroid, Platform } from 'react-native';
import AudioRecorderPlayer, {
  AudioEncoderAndroidType,
  AudioSourceAndroidType,
  AVEncoderAudioQualityIOSType,
  OutputFormatAndroidType,
} from 'react-native-audio-recorder-player';
import type {
  AudioSet,
  RecordBackType,
} from 'react-native-audio-recorder-player';

import type { PickedFile } from '../types/ai';

/**
 * Voice-note recording on a device.
 *
 * The web build takes `voiceRecorder.web.ts` instead, which uses MediaRecorder
 * directly. This library does ship a web implementation, but it returns a URI
 * string rather than a Blob — and the browser's FormData needs the Blob, or the
 * part uploads as "[object Object]". Hence the separate web path.
 *
 * Output is **m4a/AAC** on both platforms, which is on the backend's audio
 * allowlist (`audio/m4a`, `audio/x-m4a` and `audio/mp4` all map to `.m4a` in
 * upload.middleware.js). Recording to a format the server would reject is the
 * kind of failure that only surfaces after a slow upload, so the encoder is
 * pinned rather than left to the platform default.
 *
 * `AudioRecorderPlayer` is exported as a **singleton instance**, not a class,
 * so it is used directly rather than constructed.
 */

export interface RecordingState {
  /** Milliseconds elapsed. */
  durationMs: number;
}

const FILE_NAME = 'genie-voice-note.m4a';

/** MPEG-4 container, AAC encoder — an .m4a the backend accepts. */
const AUDIO_SET: AudioSet = {
  AudioSourceAndroid: AudioSourceAndroidType.MIC,
  OutputFormatAndroid: OutputFormatAndroidType.MPEG_4,
  AudioEncoderAndroid: AudioEncoderAndroidType.AAC,
  // 'aac' is a member of the AVEncodingOption string union, not an enum.
  AVFormatIDKeyIOS: 'aac',
  AVEncoderAudioQualityKeyIOS: AVEncoderAudioQualityIOSType.HIGH,
  AVNumberOfChannelsKeyIOS: 1,
};

export const voiceRecorder = {
  /** Mirrors the web module's capability probe. Native can always record. */
  isSupported: true,

  /**
   * Asks for microphone access.
   *
   * Android needs the runtime grant; iOS prompts on first record from the
   * Info.plist usage description.
   */
  async requestPermission(): Promise<boolean> {
    if (Platform.OS !== 'android') {
      return true;
    }

    const result = await PermissionsAndroid.request(
      PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
      {
        title: 'Microphone access',
        message:
          'Genie Law needs your microphone to record a voice note for the AI assistant.',
        buttonPositive: 'Allow',
        buttonNegative: 'Not now',
      },
    );

    return result === PermissionsAndroid.RESULTS.GRANTED;
  },

  /**
   * Starts recording.
   *
   * @param onTick fired on the library's subscription interval with the
   *   elapsed duration.
   */
  async start(onTick: (state: RecordingState) => void): Promise<void> {
    AudioRecorderPlayer.addRecordBackListener((meta: RecordBackType) => {
      onTick({ durationMs: meta.currentPosition });
    });

    // No uri: the library picks a platform-appropriate temporary path and
    // returns it from stopRecorder().
    await AudioRecorderPlayer.startRecorder(undefined, AUDIO_SET);
  },

  /** Stops and returns the file, ready to append to the upload. */
  async stop(): Promise<PickedFile> {
    // v5 widened stopRecorder() from `string` to `string | {filePath, duration}`,
    // so narrow before the uri reaches FormData — an object here would upload as
    // "[object Object]".
    const result = await AudioRecorderPlayer.stopRecorder();
    const uri = typeof result === 'string' ? result : result.filePath;
    AudioRecorderPlayer.removeRecordBackListener();

    return {
      uri,
      name: FILE_NAME,
      // Named explicitly: a file:// path alone leaves the type to be guessed
      // from the extension, and the server's allowlist checks MIME first.
      type: 'audio/m4a',
      // Unknown without reading the file. The server enforces the 10 MB
      // ceiling, and a voice note of any reasonable length is far below it.
      size: null,
    };
  },

  /** Stops and discards. Safe to call when not recording. */
  async cancel(): Promise<void> {
    try {
      await AudioRecorderPlayer.stopRecorder();
      AudioRecorderPlayer.removeRecordBackListener();
    } catch {
      // Not recording, or already stopped. Cancelling is best-effort by
      // design — the caller is discarding the result either way.
    }
  },
};
