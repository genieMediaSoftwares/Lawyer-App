import {
  aiMaxFileBytes,
  aiOptimizeMaxBytes,
  maxAiFileBytes,
  oversizedDocumentReason,
  rejectionReasonFor,
} from '../src/api/aiApi';
import { env } from '../src/config/env';
import type { PickedFile } from '../src/types/ai';

const MB = 1024 * 1024;
const file = (name: string, size: number | null, extra: Partial<PickedFile> = {}): PickedFile => ({
  uri: `file:///${name}`,
  name,
  type: 'application/pdf',
  size,
  ...extra,
});

describe('AI upload size limits', () => {
  const original = { upload: env.aiUploadMaxMb, optimize: env.aiOptimizeMaxMb };
  afterEach(() => {
    env.aiUploadMaxMb = original.upload;
    env.aiOptimizeMaxMb = original.optimize;
  });

  it('defaults to 3 MB per final file and 20 MB per optimization input', () => {
    env.aiUploadMaxMb = 3;
    env.aiOptimizeMaxMb = 20;
    expect(aiMaxFileBytes()).toBe(3 * MB);
    expect(aiOptimizeMaxBytes()).toBe(20 * MB);
  });

  it('never lets the optimization input fall below the final limit', () => {
    env.aiUploadMaxMb = 3;
    env.aiOptimizeMaxMb = 1;
    expect(aiOptimizeMaxBytes()).toBe(3 * MB);
  });

  it('refuses to send an original over the final limit', () => {
    env.aiUploadMaxMb = 3;
    expect(oversizedDocumentReason([file('ok.pdf', 3 * MB)])).toBeNull();
    expect(oversizedDocumentReason([file('big.pdf', 3 * MB + 1)])).toMatch(
      /big\.pdf is 3\.0 MB, over the 3\.0 MB limit/,
    );
  });

  it('does not count a server-optimized PDF, which is sent by token', () => {
    env.aiUploadMaxMb = 3;
    expect(
      oversizedDocumentReason([file('held.pdf', 8 * MB, { preparedToken: 'a'.repeat(32) })]),
    ).toBeNull();
  });

  it('caps a single acknowledgement upload at the same final limit', () => {
    env.aiUploadMaxMb = 3;
    expect(maxAiFileBytes()).toBe(3 * MB);
    expect(rejectionReasonFor(file('big.pdf', 4 * MB))).toMatch(/over the 3\.0 MB limit/);
    expect(rejectionReasonFor(file('ok.pdf', 2 * MB))).toBeNull();
  });

  it('never allows more than the backend 10 MB per file, however high the limit', () => {
    env.aiUploadMaxMb = 50;
    expect(maxAiFileBytes()).toBe(10 * MB);
  });
});
