import {
  maxAiFileBytes,
  maxAiUploadBytes,
  rejectionReasonFor,
  uploadTooLargeReason,
} from '../src/api/aiApi';
import { env } from '../src/config/env';
import type { PickedFile } from '../src/types/ai';

const MB = 1024 * 1024;
const file = (name: string, size: number | null): PickedFile => ({
  uri: `file:///${name}`,
  name,
  type: 'application/pdf',
  size,
});

describe('AI upload size limits', () => {
  const original = env.aiUploadMaxMb;
  afterEach(() => {
    env.aiUploadMaxMb = original;
  });

  it('with a 1 MB server ceiling, caps each file at 1 MB too', () => {
    env.aiUploadMaxMb = 1;
    expect(maxAiUploadBytes()).toBe(MB);
    expect(maxAiFileBytes()).toBe(MB);
    expect(rejectionReasonFor(file('big.pdf', 2 * MB))).toMatch(/over the 1\.0 MB limit/);
    expect(rejectionReasonFor(file('ok.pdf', MB / 2))).toBeNull();
  });

  it('refuses an upload whose files add up to more than the ceiling', () => {
    env.aiUploadMaxMb = 1;
    const reason = uploadTooLargeReason([file('a.pdf', 0.6 * MB), file('b.pdf', 0.6 * MB)]);
    expect(reason).toMatch(/add up to 1\.2 MB.*at most 1\.0 MB/);
    expect(uploadTooLargeReason([file('a.pdf', 0.4 * MB), null])).toBeNull();
  });

  it('never allows more than the backend 10 MB per file, however high the ceiling', () => {
    env.aiUploadMaxMb = 110;
    expect(maxAiFileBytes()).toBe(10 * MB);
  });

  it('with no ceiling configured, falls back to the per-file limit only', () => {
    env.aiUploadMaxMb = null;
    expect(maxAiUploadBytes()).toBeNull();
    expect(uploadTooLargeReason([file('a.pdf', 50 * MB)])).toBeNull();
  });
});
