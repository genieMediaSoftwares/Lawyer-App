// Regressions for uploads that worked on web but failed in the Android APK.

jest.mock('../src/api/apiClient', () => ({
  apiClient: { post: jest.fn() },
  UPLOAD_TIMEOUT_MS: 120000,
  unwrap: (response: { data: { data: unknown } }) => response.data.data,
}));

import AudioRecorderPlayer from 'react-native-audio-recorder-player';

import { apiClient } from '../src/api/apiClient';
import { authApi } from '../src/api/authApi';
import { voiceRecorder } from '../src/services/voiceRecorder';

const fieldNamesOf = (form: FormData): string[] =>
  Array.from((form as unknown as { keys: () => Iterable<string> }).keys());

describe('voiceRecorder (Android)', () => {
  it('returns a file:// URI so React Native can read the recording for multipart upload', async () => {
    // The native module resolves a bare absolute path with no scheme.
    (AudioRecorderPlayer.stopRecorder as jest.Mock).mockResolvedValue({
      filePath: '/data/user/0/com.frontend/files/sound_1700000000000.mp4',
      duration: 4200,
    });

    const file = await voiceRecorder.stop();

    expect(file.uri).toBe('file:///data/user/0/com.frontend/files/sound_1700000000000.mp4');
    expect(file.type).toBe('audio/m4a');
  });

  it('leaves URIs that already have a scheme untouched', async () => {
    (AudioRecorderPlayer.stopRecorder as jest.Mock).mockResolvedValue(
      'file:///data/user/0/com.frontend/cache/sound.mp4',
    );

    const file = await voiceRecorder.stop();

    expect(file.uri).toBe('file:///data/user/0/com.frontend/cache/sound.mp4');
  });
});

describe('authApi.uploadProfileImage', () => {
  it('sends the photo in the "image" field the backend route expects', async () => {
    (apiClient.post as jest.Mock).mockResolvedValue({ data: { data: { _id: 'u1' } } });

    await authApi.uploadProfileImage({
      uri: 'content://media/picker/0/42',
      name: 'IMG_0042.jpg',
      type: 'image/jpeg',
    });

    const [url, form] = (apiClient.post as jest.Mock).mock.calls[0];
    expect(url).toBe('/auth/profile/image');
    expect(fieldNamesOf(form)).toEqual(['image']);
  });
});
