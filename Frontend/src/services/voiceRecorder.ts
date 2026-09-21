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
    AudioRecorderPlayer.addRecordBackListener((meta: RecordBackType) => {
      onTick({ durationMs: meta.currentPosition });
    });

    await AudioRecorderPlayer.startRecorder(undefined, AUDIO_SET);
  },

  async stop(): Promise<PickedFile> {
    const result = await AudioRecorderPlayer.stopRecorder();
    const uri = typeof result === 'string' ? result : result.filePath;
    AudioRecorderPlayer.removeRecordBackListener();

    return {
      uri,
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
