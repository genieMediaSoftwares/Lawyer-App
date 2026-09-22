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

export interface RecordingState {
  durationMs: number;
}

const FILE_NAME = 'genie-voice-note.m4a';

// The Android recorder resolves a bare absolute path (/data/user/0/…/sound_*.mp4).
// React Native's multipart upload opens each file with
// ContentResolver.openInputStream(Uri.parse(uri)); a path with no scheme is
// treated as a content-provider lookup and fails ("Could not retrieve file for
// contentUri …" in Logcat), which surfaced as a network error on upload.
const toFileUri = (path: string): string =>
  path.startsWith('/') ? `file://${path}` : path;

const AUDIO_SET: AudioSet = {
  AudioSourceAndroid: AudioSourceAndroidType.MIC,
  OutputFormatAndroid: OutputFormatAndroidType.MPEG_4,
  AudioEncoderAndroid: AudioEncoderAndroidType.AAC,
  AVFormatIDKeyIOS: 'aac',
  AVEncoderAudioQualityKeyIOS: AVEncoderAudioQualityIOSType.HIGH,
  AVNumberOfChannelsKeyIOS: 1,
};

export const voiceRecorder = {
  isSupported: true,

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

  async start(onTick: (state: RecordingState) => void): Promise<void> {
    // The native recorder defaults to an event every 60ms, and each one became
    // a setState that re-rendered the whole screen ~17x/second for the entire
    // recording. The UI shows whole seconds, so ask for 4 events/second and
    // forward only when the displayed second changes.
    AudioRecorderPlayer.setSubscriptionDuration(0.25);
    let lastSecond = -1;
    AudioRecorderPlayer.addRecordBackListener((meta: RecordBackType) => {
      const second = Math.floor(meta.currentPosition / 1000);
      if (second !== lastSecond) {
        lastSecond = second;
        onTick({ durationMs: second * 1000 });
      }
    });

    await AudioRecorderPlayer.startRecorder(undefined, AUDIO_SET);
  },

  async stop(): Promise<PickedFile> {
    const result = await AudioRecorderPlayer.stopRecorder();
    const path = typeof result === 'string' ? result : result.filePath;
    AudioRecorderPlayer.removeRecordBackListener();

    return {
      uri: toFileUri(path),
      name: FILE_NAME,
      type: 'audio/m4a',
      size: null,
    };
  },

  async cancel(): Promise<void> {
    try {
      await AudioRecorderPlayer.stopRecorder();
      AudioRecorderPlayer.removeRecordBackListener();
    } catch {
    }
  },
};
