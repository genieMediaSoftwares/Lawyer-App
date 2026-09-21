import { AxiosError, AxiosHeaders } from 'axios';

import { aiApi, knownTotalBytes } from '../src/api/aiApi';
import { apiClient } from '../src/api/apiClient';
import {
  IMAGE_STEPS,
  describeOptimization,
  detectKind,
  prepareAiFile,
  prepareAiFiles,
} from '../src/services/aiFileOptimizer';
import type { PickedFile } from '../src/types/ai';

jest.mock('../src/services/imageCompressor', () => ({
  imageCompressor: { compress: jest.fn() },
}));

const { imageCompressor } = jest.requireMock('../src/services/imageCompressor');

const MB = 1024 * 1024;

const picked = (name: string, size: number | null, type: string | null): PickedFile => ({
  uri: `file:///picked/${name}`,
  name,
  type,
  size,
});

const jpeg = (size: number): PickedFile => ({
  uri: 'file:///cache/out.jpg',
  name: 'out.jpg',
  type: 'image/jpeg',
  size,
});

let optimizePdf: jest.SpyInstance;

beforeEach(() => {
  imageCompressor.compress.mockReset();
  optimizePdf = jest.spyOn(aiApi, 'optimizePdf').mockReset();
});

afterAll(() => {
  optimizePdf.mockRestore();
});

describe('files of 3 MB or less', () => {
  it.each([
    ['photo.jpg', 'image/jpeg'],
    ['fir.pdf', 'application/pdf'],
    ['notes.docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
    ['notes.txt', 'text/plain'],
  ])('%s at exactly 3 MB is uploaded as picked, never compressed', async (name, type) => {
    const file = picked(name, 3 * MB, type);

    const outcome = await prepareAiFile(file);

    expect(outcome).toEqual({ ok: true, file });
    expect(imageCompressor.compress).not.toHaveBeenCalled();
    expect(optimizePdf).not.toHaveBeenCalled();
  });
});

describe('images over 3 MB', () => {
  it('are compressed on the device and report the size change', async () => {
    imageCompressor.compress.mockResolvedValueOnce(jpeg(2 * MB));
    const stages: string[] = [];

    const outcome = await prepareAiFile(picked('scan.png', 8 * MB, 'image/png'), stage =>
      stages.push(stage),
    );

    expect(outcome.ok).toBe(true);
    if (!outcome.ok) return;
    expect(outcome.file.size).toBe(2 * MB);
    expect(outcome.file.optimization).toEqual({ method: 'compressed', originalSize: 8 * MB });
    expect(describeOptimization(outcome.file)).toBe('Compressed from 8.0 MB to 2.0 MB');
    expect(stages).toEqual(['reading', 'compressing']);
    expect(imageCompressor.compress).toHaveBeenCalledTimes(1);
    expect(optimizePdf).not.toHaveBeenCalled();
  });

  it('are recompressed with stronger settings until they fit', async () => {
    imageCompressor.compress
      .mockResolvedValueOnce(jpeg(4 * MB))
      .mockResolvedValueOnce(jpeg(3.5 * MB))
      .mockResolvedValueOnce(jpeg(2.9 * MB));

    const outcome = await prepareAiFile(picked('photo.jpg', 12 * MB, 'image/jpeg'));

    expect(outcome.ok).toBe(true);
    expect(imageCompressor.compress).toHaveBeenCalledTimes(3);
    expect(imageCompressor.compress.mock.calls.map((c: unknown[]) => c[1])).toEqual(IMAGE_STEPS);
  });

  it('are rejected gracefully when still over 3 MB after every pass', async () => {
    imageCompressor.compress.mockResolvedValue(jpeg(3.4 * MB));

    const outcome = await prepareAiFile(picked('huge.jpg', 20 * MB, 'image/jpeg'));

    expect(outcome.ok).toBe(false);
    if (outcome.ok) return;
    expect(outcome.reason).toContain('huge.jpg');
    expect(outcome.reason).toContain('3.4 MB');
    expect(outcome.reason).toContain('3.0 MB limit');
    expect(imageCompressor.compress).toHaveBeenCalledTimes(IMAGE_STEPS.length);
  });

  it('are rejected without trying when too large to compress on the device', async () => {
    const outcome = await prepareAiFile(picked('raw.png', 40 * MB, 'image/png'));

    expect(outcome.ok).toBe(false);
    expect(imageCompressor.compress).not.toHaveBeenCalled();
  });

  it('report a compressor failure instead of crashing', async () => {
    imageCompressor.compress.mockRejectedValue(new Error('decode failed'));

    const outcome = await prepareAiFile(picked('bad.jpg', 5 * MB, 'image/jpeg'));

    expect(outcome.ok).toBe(false);
    if (outcome.ok) return;
    expect(outcome.reason).toContain('bad.jpg could not be compressed');
  });
});

describe('PDFs over 3 MB', () => {
  it('are optimized on the server and sent later by token', async () => {
    optimizePdf.mockResolvedValue({
      token: 'a'.repeat(32),
      name: 'fir.pdf',
      mimeType: 'application/pdf',
      size: 2.2 * MB,
      originalSize: 9 * MB,
      optimized: true,
    });

    const outcome = await prepareAiFile(picked('fir.pdf', 9 * MB, 'application/pdf'));

    expect(outcome.ok).toBe(true);
    if (!outcome.ok) return;
    expect(outcome.file.preparedToken).toBe('a'.repeat(32));
    expect(outcome.file.optimization).toEqual({ method: 'optimized', originalSize: 9 * MB });
    expect(imageCompressor.compress).not.toHaveBeenCalled();
  });

  it("are rejected with the server's reason when they cannot be reduced enough", async () => {
    const config = { headers: new AxiosHeaders() };
    optimizePdf.mockRejectedValue(
      new AxiosError('fail', 'ERR_BAD_REQUEST', config, null, {
        status: 422,
        statusText: '',
        data: { success: false, message: 'This PDF could only be reduced to 4.1 MB.' },
        headers: {},
        config,
      }),
    );

    const outcome = await prepareAiFile(picked('scan.pdf', 15 * MB, 'application/pdf'));

    expect(outcome).toEqual({
      ok: false,
      reason: 'scan.pdf: This PDF could only be reduced to 4.1 MB.',
    });
  });

  it('over 20 MB are rejected without uploading them', async () => {
    const outcome = await prepareAiFile(picked('book.pdf', 25 * MB, 'application/pdf'));

    expect(outcome.ok).toBe(false);
    expect(optimizePdf).not.toHaveBeenCalled();
  });
});

describe('DOCX and text over 3 MB', () => {
  it.each([
    ['brief.docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', /Save it as a PDF/],
    ['transcript.txt', 'text/plain', /never altered/],
    ['ledger.csv', 'text/csv', /never altered/],
  ])('%s is refused and never modified or uploaded', async (name, type, message) => {
    const outcome = await prepareAiFile(picked(name, 5 * MB, type));

    expect(outcome.ok).toBe(false);
    if (outcome.ok) return;
    expect(outcome.reason).toMatch(message);
    expect(imageCompressor.compress).not.toHaveBeenCalled();
    expect(optimizePdf).not.toHaveBeenCalled();
  });
});

describe('size and type detection', () => {
  it('reads the actual size when the picker did not report one', async () => {
    const fetchSpy = jest
      .spyOn(global, 'fetch')
      .mockResolvedValue({ blob: async () => ({ size: 6 * MB }) } as unknown as Response);
    imageCompressor.compress.mockResolvedValueOnce(jpeg(1.5 * MB));

    const outcome = await prepareAiFile(picked('unknown.jpg', null, 'image/jpeg'));

    expect(fetchSpy).toHaveBeenCalledWith('file:///picked/unknown.jpg');
    expect(outcome.ok).toBe(true);
    expect(imageCompressor.compress).toHaveBeenCalledTimes(1);
    fetchSpy.mockRestore();
  });

  it('detects the kind from the extension when the type is missing', () => {
    expect(detectKind(picked('a.JPG', 1, null))).toBe('image');
    expect(detectKind(picked('a.pdf', 1, null))).toBe('pdf');
    expect(detectKind(picked('a.docx', 1, null))).toBe('docx');
    expect(detectKind(picked('a.md', 1, null))).toBe('text');
  });

  it('refuses unsupported types before touching them', async () => {
    const outcome = await prepareAiFile(picked('old.doc', 5 * MB, 'application/msword'));

    expect(outcome.ok).toBe(false);
    expect(imageCompressor.compress).not.toHaveBeenCalled();
  });
});

describe('several files at once', () => {
  it('keeps the ones that fit and explains the ones that do not', async () => {
    imageCompressor.compress.mockResolvedValueOnce(jpeg(MB));

    const result = await prepareAiFiles([
      picked('small.pdf', MB, 'application/pdf'),
      picked('big.jpg', 7 * MB, 'image/jpeg'),
      picked('huge.txt', 4 * MB, 'text/plain'),
    ]);

    expect(result.ready.map(f => f.name)).toEqual(['small.pdf', 'out.jpg']);
    expect(result.rejections).toHaveLength(1);
    expect(result.rejections[0]).toContain('huge.txt');
  });
});

describe('sending the analysis', () => {
  it('sends an optimized PDF by token and other files as uploads', async () => {
    const appended: [string, unknown][] = [];
    const RealFormData = global.FormData;
    (global as any).FormData = class {
      append(name: string, value: unknown) {
        appended.push([name, value]);
      }
    };
    const post = jest
      .spyOn(apiClient, 'post')
      .mockResolvedValue({ data: { success: true, data: { sessionId: 's-1' } } });

    try {
      await aiApi.analyze({
        documents: [
          picked('small.pdf', MB, 'application/pdf'),
          { ...picked('big.pdf', 2 * MB, 'application/pdf'), preparedToken: 'b'.repeat(32) },
        ],
        requestId: 'req-1',
      });
    } finally {
      global.FormData = RealFormData;
      post.mockRestore();
    }

    const documents = appended.filter(([name]) => name === 'documents');
    expect(documents.map(([, value]) => (value as { name: string }).name)).toEqual(['small.pdf']);
    expect(appended.filter(([name]) => name === 'preparedDocuments')).toEqual([
      ['preparedDocuments', 'b'.repeat(32)],
    ]);
  });

  it('does not count server-held PDFs toward this upload size', () => {
    expect(
      knownTotalBytes([
        picked('a.pdf', MB, 'application/pdf'),
        { ...picked('b.pdf', 2 * MB, 'application/pdf'), preparedToken: 'c'.repeat(32) },
      ]),
    ).toBe(MB);
  });
});
