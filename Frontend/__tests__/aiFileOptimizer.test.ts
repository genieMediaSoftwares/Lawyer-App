import { AxiosError, AxiosHeaders } from 'axios';

import { aiApi, knownTotalBytes } from '../src/api/aiApi';
import { apiClient } from '../src/api/apiClient';
import { env } from '../src/config/env';
import {
  IMAGE_STEPS,
  describeOptimization,
  detectKind,
  prepareAiFile,
  prepareAiFiles,
  progressLabel,
} from '../src/services/aiFileOptimizer';
import type { PrepareProgress } from '../src/services/aiFileOptimizer';
import type { PickedFile } from '../src/types/ai';

jest.mock('../src/services/imageCompressor', () => ({
  imageCompressor: { compress: jest.fn() },
}));

const { imageCompressor } = jest.requireMock('../src/services/imageCompressor');

const MB = 1024 * 1024;
const KB = 1024;

const picked = (name: string, size: number | null, type: string | null): PickedFile => ({
  uri: `file:///picked/${name}`,
  name,
  type,
  size,
});

const pdf = (name: string, size: number) => picked(name, size, 'application/pdf');

const jpeg = (size: number): PickedFile => ({
  uri: 'file:///cache/out.jpg',
  name: 'out.jpg',
  type: 'image/jpeg',
  size,
});

const httpError = (status: number, message?: string) => {
  const config = { headers: new AxiosHeaders() };
  return new AxiosError('fail', 'ERR_BAD_REQUEST', config, null, {
    status,
    statusText: '',
    data: message ? { success: false, message } : '<html>413</html>',
    headers: {},
    config,
  });
};

const optimized = (size: number, originalSize: number, name = 'fir.pdf') => ({
  token: 'a'.repeat(32),
  name,
  mimeType: 'application/pdf',
  size,
  originalSize,
  optimized: true,
});

let optimizePdf: jest.SpyInstance;
const saved = { upload: env.aiUploadMaxMb, optimize: env.aiOptimizeMaxMb };

beforeEach(() => {
  // The limits the product ships with, independent of any local .env.
  env.aiUploadMaxMb = 3;
  env.aiOptimizeMaxMb = 20;
  imageCompressor.compress.mockReset();
  optimizePdf = jest.spyOn(aiApi, 'optimizePdf').mockReset();
});

afterAll(() => {
  env.aiUploadMaxMb = saved.upload;
  env.aiOptimizeMaxMb = saved.optimize;
  optimizePdf.mockRestore();
});

describe('PDF size matrix', () => {
  it.each([
    ['500 KB', 500 * KB],
    ['2 MB', 2 * MB],
    ['3 MB', 3 * MB],
  ])('%s is uploaded directly, never sent for optimization', async (_label, size) => {
    const file = pdf('doc.pdf', size);

    const outcome = await prepareAiFile(file);

    expect(outcome).toEqual({ ok: true, file });
    expect(optimizePdf).not.toHaveBeenCalled();
  });

  it.each([
    ['4 MB', 4 * MB],
    ['8 MB', 8 * MB],
    ['20 MB', 20 * MB],
  ])('%s is optimized, and only the optimized copy is queued', async (_label, size) => {
    optimizePdf.mockResolvedValue(optimized(2.8 * MB, size));

    const outcome = await prepareAiFile(pdf('big.pdf', size));

    expect(optimizePdf).toHaveBeenCalledTimes(1);
    expect(outcome.ok).toBe(true);
    if (!outcome.ok) return;
    expect(outcome.file.preparedToken).toBe('a'.repeat(32));
    expect(outcome.file.size).toBe(2.8 * MB);
    expect(outcome.file.uri).toBe('');
    expect(outcome.file.file).toBeUndefined();
  });

  it('21 MB is refused before any upload', async () => {
    const outcome = await prepareAiFile(pdf('big.pdf', 21 * MB));

    expect(outcome).toEqual({
      ok: false,
      reason: 'big.pdf: This file is too large to optimize. Maximum optimization input is 20.0 MB.',
    });
    expect(optimizePdf).not.toHaveBeenCalled();
  });
});

describe('the real-world case: a 7.4 MB court PDF', () => {
  it('is optimized to 2.8 MB and reported as such', async () => {
    optimizePdf.mockResolvedValue(
      optimized(2.8 * MB, 7.4 * MB, 'Cr_77_26_Giri Murugan.pdf'),
    );
    const stages: string[] = [];

    const outcome = await prepareAiFile(pdf('Cr_77_26_Giri Murugan.pdf', 7.4 * MB), stage =>
      stages.push(stage),
    );

    expect(stages).toEqual(['reading', 'optimizing']);
    expect(outcome.ok).toBe(true);
    if (!outcome.ok) return;
    expect(describeOptimization(outcome.file)).toBe(
      'File optimized successfully · Original: 7.4 MB · Optimized: 2.8 MB',
    );
  });
});

describe('optimize request failures', () => {
  it('a server that still cannot reach 3 MB is reported with its reason', async () => {
    optimizePdf.mockRejectedValue(
      httpError(
        422,
        'Unable to reduce this PDF below 3.0 MB without compromising document quality.',
      ),
    );

    const outcome = await prepareAiFile(pdf('scan.pdf', 15 * MB));

    expect(outcome).toEqual({
      ok: false,
      reason:
        'scan.pdf: Unable to reduce this PDF below 3.0 MB without compromising document quality.',
    });
  });

  it('a proxy 413 says the file is too large to optimize', async () => {
    optimizePdf.mockRejectedValue(httpError(413));

    const outcome = await prepareAiFile(pdf('scan.pdf', 7 * MB));

    expect(outcome.ok).toBe(false);
    if (outcome.ok) return;
    expect(outcome.reason).toMatch(/too large to optimize\. Maximum optimization input is 20\.0 MB/);
  });

  it('a missing endpoint says optimization is not available yet', async () => {
    optimizePdf.mockRejectedValue(httpError(404, 'Not found'));

    const outcome = await prepareAiFile(pdf('scan.pdf', 7 * MB));

    expect(outcome.ok).toBe(false);
    if (outcome.ok) return;
    expect(outcome.reason).toMatch(/not available on the server yet/);
  });

  it('a server error does not leak internals', async () => {
    optimizePdf.mockRejectedValue(httpError(500, 'TypeError: cannot read x of undefined'));

    const outcome = await prepareAiFile(pdf('scan.pdf', 7 * MB));

    expect(outcome.ok).toBe(false);
    if (outcome.ok) return;
    expect(outcome.reason).toBe('scan.pdf: The server could not optimize this file. Please try again.');
  });

  it('a network failure or timeout is reported, not treated as success', async () => {
    const config = { headers: new AxiosHeaders() };
    optimizePdf.mockRejectedValue(new AxiosError('timeout', 'ECONNABORTED', config as any));

    const outcome = await prepareAiFile(pdf('scan.pdf', 7 * MB));

    expect(outcome.ok).toBe(false);
    if (outcome.ok) return;
    expect(outcome.reason).toMatch(/could not be sent for optimization/);
  });

  it('a result the server says is still too large is never kept', async () => {
    optimizePdf.mockResolvedValue(optimized(3.2 * MB, 7 * MB));

    const outcome = await prepareAiFile(pdf('scan.pdf', 7 * MB));

    expect(outcome).toEqual({
      ok: false,
      reason: 'scan.pdf: This file could not be safely reduced below 3.0 MB.',
    });
  });
});

describe('images over 3 MB', () => {
  it('are compressed on the device', async () => {
    imageCompressor.compress.mockResolvedValueOnce(jpeg(2 * MB));

    const outcome = await prepareAiFile(picked('scan.png', 8 * MB, 'image/png'));

    expect(outcome.ok).toBe(true);
    if (!outcome.ok) return;
    expect(outcome.file.optimization).toEqual({ method: 'compressed', originalSize: 8 * MB });
    expect(optimizePdf).not.toHaveBeenCalled();
  });

  it('are recompressed with stronger settings until they fit', async () => {
    imageCompressor.compress
      .mockResolvedValueOnce(jpeg(4 * MB))
      .mockResolvedValueOnce(jpeg(3.5 * MB))
      .mockResolvedValueOnce(jpeg(2.9 * MB));

    const outcome = await prepareAiFile(picked('photo.jpg', 12 * MB, 'image/jpeg'));

    expect(outcome.ok).toBe(true);
    expect(imageCompressor.compress.mock.calls.map((c: unknown[]) => c[1])).toEqual(IMAGE_STEPS);
  });

  it('are rejected gracefully when still over 3 MB after every pass', async () => {
    imageCompressor.compress.mockResolvedValue(jpeg(3.4 * MB));

    const outcome = await prepareAiFile(picked('huge.jpg', 18 * MB, 'image/jpeg'));

    expect(outcome.ok).toBe(false);
    if (outcome.ok) return;
    expect(outcome.reason).toContain('could not be safely reduced below 3.0 MB');
    expect(outcome.reason).toContain('3.4 MB');
  });

  it('over 20 MB are refused without trying', async () => {
    const outcome = await prepareAiFile(picked('raw.png', 21 * MB, 'image/png'));

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

describe('DOCX and text over 3 MB', () => {
  it.each([
    ['brief.docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', /Save it as a PDF/],
    ['transcript.txt', 'text/plain', /never altered/],
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
      .spyOn(globalThis, 'fetch')
      .mockResolvedValue({ blob: async () => ({ size: 6 * MB }) } as unknown as Response);
    optimizePdf.mockResolvedValue(optimized(2 * MB, 6 * MB));

    const outcome = await prepareAiFile(pdf('unknown.pdf', null as unknown as number));

    expect(fetchSpy).toHaveBeenCalledWith('file:///picked/unknown.pdf');
    expect(outcome.ok).toBe(true);
    expect(optimizePdf).toHaveBeenCalledTimes(1);
    fetchSpy.mockRestore();
  });

  it('detects the kind from the extension when the type is missing', () => {
    expect(detectKind(picked('a.JPG', 1, null))).toBe('image');
    expect(detectKind(picked('a.pdf', 1, null))).toBe('pdf');
    expect(detectKind(picked('a.docx', 1, null))).toBe('docx');
    expect(detectKind(picked('a.md', 1, null))).toBe('text');
  });
});

describe('several files at once', () => {
  it('are optimized one at a time, with "n of m" progress', async () => {
    let inFlight = 0;
    let maxInFlight = 0;
    optimizePdf.mockImplementation(async (file: PickedFile) => {
      inFlight += 1;
      maxInFlight = Math.max(maxInFlight, inFlight);
      await new Promise<void>(resolve => setTimeout(resolve, 5));
      inFlight -= 1;
      return optimized(2 * MB, file.size ?? 0, file.name);
    });
    const labels: string[] = [];

    const result = await prepareAiFiles(
      [
        pdf('a.pdf', MB),
        pdf('b.pdf', 8 * MB),
        pdf('c.pdf', 9 * MB),
        pdf('d.pdf', 21 * MB),
      ],
      (progress: PrepareProgress) => labels.push(progressLabel(progress)),
    );

    expect(maxInFlight).toBe(1);
    expect(optimizePdf).toHaveBeenCalledTimes(2);
    expect(result.ready.map(f => f.name)).toEqual(['a.pdf', 'b.pdf', 'c.pdf']);
    expect(result.rejections).toEqual([
      'd.pdf: This file is too large to optimize. Maximum optimization input is 20.0 MB.',
    ]);
    expect(labels).toContain('Optimizing 2 of 4 files · Optimizing b.pdf...');
    expect(labels).toContain('Optimizing 3 of 4 files · Optimizing c.pdf...');
  });

  it('a single file shows just its own name', () => {
    expect(
      progressLabel({ file: pdf('Cr_77_26_Giri Murugan.pdf', 7 * MB), stage: 'optimizing', index: 1, total: 1 }),
    ).toBe('Optimizing Cr_77_26_Giri Murugan.pdf...');
  });
});

describe('sending the analysis', () => {
  it('sends an optimized PDF by token and never re-uploads the original', async () => {
    const appended: [string, unknown][] = [];
    const RealFormData = (globalThis as any).FormData;
    (globalThis as any).FormData = class {
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
          pdf('small.pdf', MB),
          { ...pdf('big.pdf', 2 * MB), preparedToken: 'b'.repeat(32) },
        ],
        requestId: 'req-1',
      });
    } finally {
      (globalThis as any).FormData = RealFormData;
      post.mockRestore();
    }

    const documents = appended.filter(([name]) => name === 'documents');
    expect(documents.map(([, value]) => (value as { name: string }).name)).toEqual(['small.pdf']);
    expect(appended.filter(([name]) => name === 'preparedDocuments')).toEqual([
      ['preparedDocuments', 'b'.repeat(32)],
    ]);
  });

  it('refuses to send an oversized original that skipped optimization', async () => {
    const post = jest.spyOn(apiClient, 'post');

    await expect(
      aiApi.analyze({ documents: [pdf('raw.pdf', 7 * MB)], requestId: 'req-2' }),
    ).rejects.toThrow(/raw\.pdf is 7\.0 MB, over the 3\.0 MB limit/);
    expect(post).not.toHaveBeenCalled();
    post.mockRestore();
  });

  it('does not count server-held PDFs toward this upload', () => {
    expect(
      knownTotalBytes([pdf('a.pdf', MB), { ...pdf('b.pdf', 2 * MB), preparedToken: 'c'.repeat(32) }]),
    ).toBe(MB);
  });
});
