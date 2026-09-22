// Guards the mobile performance fixes: fewer re-renders during recording and
// uploads, and profile photos resized before upload.

jest.mock('../src/api/apiClient', () => ({
  apiClient: { post: jest.fn() },
  unwrap: (response: { data: { data: unknown } }) => response.data.data,
  UPLOAD_TIMEOUT_MS: 120000,
}));

jest.mock('../src/services/filePicker', () => ({
  filePicker: { pickImage: jest.fn() },
}));

jest.mock('../src/services/imageCompressor', () => ({
  imageCompressor: { compress: jest.fn() },
}));

import AudioRecorderPlayer from 'react-native-audio-recorder-player';

import { apiClient } from '../src/api/apiClient';
import { aiApi } from '../src/api/aiApi';
import { filePicker } from '../src/services/filePicker';
import { imageCompressor } from '../src/services/imageCompressor';
import { pickProfilePhoto } from '../src/services/profilePhoto';
import { voiceRecorder } from '../src/services/voiceRecorder';

beforeEach(() => jest.clearAllMocks());

describe('voiceRecorder.start', () => {
  it('asks the native recorder for fewer events and reports only whole-second changes', async () => {
    const onTick = jest.fn();
    await voiceRecorder.start(onTick);

    expect(AudioRecorderPlayer.setSubscriptionDuration).toHaveBeenCalledWith(0.25);

    const listener = (AudioRecorderPlayer.addRecordBackListener as jest.Mock).mock.calls[0][0];
    [0, 250, 500, 750, 1000, 1250, 1999, 2000].forEach(ms =>
      listener({ currentPosition: ms }),
    );

    expect(onTick.mock.calls.map(([state]) => state.durationMs)).toEqual([0, 1000, 2000]);
  });
});

describe('aiApi.analyze upload progress', () => {
  it('reports progress only when the whole percentage changes', async () => {
    (apiClient.post as jest.Mock).mockResolvedValue({ data: { data: { sessionId: 's1' } } });
    const onUploadProgress = jest.fn();

    await aiApi.analyze({
      documents: [{ uri: 'file:///doc.pdf', name: 'doc.pdf', type: 'application/pdf', size: 10 }],
      requestId: 'r1',
      onUploadProgress,
    });

    const config = (apiClient.post as jest.Mock).mock.calls[0][2];
    [1000, 1040, 1080, 2000, 2050, 10000].forEach(loaded =>
      config.onUploadProgress({ loaded, total: 10000 }),
    );

    expect(onUploadProgress.mock.calls.map(([fraction]) => fraction)).toEqual([0.1, 0.2, 1]);
  });
});

describe('pickProfilePhoto', () => {
  const picked = (size: number | null) => ({
    uri: 'content://media/picker/0/42',
    name: 'IMG_0042.jpg',
    type: 'image/jpeg',
    size,
  });

  it('resizes a large camera photo before upload', async () => {
    (filePicker.pickImage as jest.Mock).mockResolvedValue(picked(6_000_000));
    (imageCompressor.compress as jest.Mock).mockResolvedValue({
      uri: 'file:///cache/resized.jpg',
      name: 'IMG_0042.jpg',
      type: 'image/jpeg',
      size: 420_000,
    });

    const photo = await pickProfilePhoto();

    expect(imageCompressor.compress).toHaveBeenCalledWith(
      expect.objectContaining({ size: 6_000_000 }),
      { maxDimension: 1600, quality: 0.85 },
    );
    expect(photo).toEqual({ uri: 'file:///cache/resized.jpg', name: 'IMG_0042.jpg', type: 'image/jpeg' });
  });

  it('sends a small photo as picked, without re-encoding it', async () => {
    (filePicker.pickImage as jest.Mock).mockResolvedValue(picked(300_000));

    const photo = await pickProfilePhoto();

    expect(imageCompressor.compress).not.toHaveBeenCalled();
    expect(photo).toEqual({ uri: 'content://media/picker/0/42', name: 'IMG_0042.jpg', type: 'image/jpeg' });
  });

  it('falls back to the original if the resizer cannot read the image', async () => {
    const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
    (filePicker.pickImage as jest.Mock).mockResolvedValue(picked(5_000_000));
    (imageCompressor.compress as jest.Mock).mockRejectedValue(new Error('unsupported'));

    const photo = await pickProfilePhoto();

    expect(photo).toEqual({ uri: 'content://media/picker/0/42', name: 'IMG_0042.jpg', type: 'image/jpeg' });
    warn.mockRestore();
  });
});
