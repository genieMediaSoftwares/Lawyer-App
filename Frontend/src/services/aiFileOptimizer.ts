import { Platform } from 'react-native';

import { AI_MAX_FILE_BYTES, aiApi, unsupportedTypeReason } from '../api/aiApi';
import { imageCompressor } from './imageCompressor';
import { toAppError } from '../utils/errors';
import { formatFileSize } from '../utils/format';
import type { ImageCompressionStep, PickedFile } from '../types/ai';

const MB = 1024 * 1024;

// Largest originals worth attempting: bigger images exhaust device memory and
// bigger PDFs are refused by the server's optimizer.
export const MAX_IMAGE_INPUT_BYTES = 25 * MB;
export const MAX_PDF_INPUT_BYTES = 20 * MB;

// Each pass is stronger than the last; stop at the first that fits.
export const IMAGE_STEPS: readonly ImageCompressionStep[] = [
  { maxDimension: 2560, quality: 0.82 },
  { maxDimension: 2048, quality: 0.72 },
  { maxDimension: 1600, quality: 0.62 },
];

export type FileKind = 'image' | 'pdf' | 'docx' | 'text' | 'other';

export type PrepareStage = 'reading' | 'compressing' | 'optimizing';

export type PrepareOutcome =
  | { ok: true; file: PickedFile }
  | { ok: false; reason: string };

const extensionOf = (name: string): string =>
  (/\.([a-z0-9]+)$/i.exec(name)?.[1] ?? '').toLowerCase();

export const detectKind = (file: PickedFile): FileKind => {
  const ext = extensionOf(file.name);
  const type = (file.type ?? '').toLowerCase();

  if (type.startsWith('image/') || ['jpg', 'jpeg', 'png', 'webp'].includes(ext)) {
    return 'image';
  }
  if (type === 'application/pdf' || ext === 'pdf') {
    return 'pdf';
  }
  if (type.includes('wordprocessingml') || ext === 'docx') {
    return 'docx';
  }
  if (type.startsWith('text/') || ['txt', 'md', 'csv'].includes(ext)) {
    return 'text';
  }
  return 'other';
};

export const readActualSize = async (file: PickedFile): Promise<number | null> => {
  if (typeof file.size === 'number' && Number.isFinite(file.size)) {
    return file.size;
  }
  if (Platform.OS === 'web') {
    const blob = file.file as { size?: number } | undefined;
    return typeof blob?.size === 'number' ? blob.size : null;
  }
  try {
    const response = await fetch(file.uri);
    return (await response.blob()).size;
  } catch {
    return null;
  }
};

const tooLarge = (name: string, size: number, what: string) =>
  `${name} is ${formatFileSize(size)}. ${what} Please upload a smaller file (${formatFileSize(
    AI_MAX_FILE_BYTES,
  )} or less).`;

async function compressImage(
  file: PickedFile,
  size: number,
): Promise<PrepareOutcome> {
  if (size > MAX_IMAGE_INPUT_BYTES) {
    return {
      ok: false,
      reason: tooLarge(file.name, size, 'This image is too large to compress on this device.'),
    };
  }

  let smallest: number | null = null;
  for (const step of IMAGE_STEPS) {
    let candidate: PickedFile;
    try {
      candidate = await imageCompressor.compress(file, step);
    } catch (error) {
      return {
        ok: false,
        reason: `${file.name} could not be compressed: ${toAppError(error).message}`,
      };
    }

    const candidateSize = await readActualSize(candidate);
    if (candidateSize !== null && candidateSize <= AI_MAX_FILE_BYTES) {
      return {
        ok: true,
        file: {
          ...candidate,
          size: candidateSize,
          optimization: { method: 'compressed', originalSize: size },
        },
      };
    }
    if (candidateSize !== null) {
      smallest = smallest === null ? candidateSize : Math.min(smallest, candidateSize);
    }
  }

  return {
    ok: false,
    reason: `${file.name} is ${formatFileSize(size)} and could only be compressed to ${
      smallest === null ? 'an unknown size' : formatFileSize(smallest)
    }, still over the ${formatFileSize(AI_MAX_FILE_BYTES)} limit. Please crop it or photograph the page at a lower resolution.`,
  };
}

async function optimizePdf(file: PickedFile, size: number): Promise<PrepareOutcome> {
  if (size > MAX_PDF_INPUT_BYTES) {
    return {
      ok: false,
      reason: tooLarge(file.name, size, 'PDFs over 20 MB are too large to optimize.'),
    };
  }

  try {
    const result = await aiApi.optimizePdf(file);
    if (result.size > AI_MAX_FILE_BYTES) {
      return {
        ok: false,
        reason: tooLarge(file.name, result.size, 'It is still too large after optimization.'),
      };
    }
    return {
      ok: true,
      file: {
        uri: '',
        name: result.name || file.name,
        type: 'application/pdf',
        size: result.size,
        preparedToken: result.token,
        optimization: { method: 'optimized', originalSize: result.originalSize || size },
      },
    };
  } catch (error) {
    return { ok: false, reason: `${file.name}: ${toAppError(error).message}` };
  }
}

/**
 * Makes one picked file ready for the AI assistant:
 * - 3 MB or less: used exactly as picked, never re-encoded.
 * - Images over 3 MB: compressed on the device, in progressively stronger passes.
 * - PDFs over 3 MB: optimized on the server.
 * - DOCX and text over 3 MB: refused. Their content is never altered.
 */
export async function prepareAiFile(
  file: PickedFile,
  onStage?: (stage: PrepareStage) => void,
): Promise<PrepareOutcome> {
  const typeReason = unsupportedTypeReason(file);
  if (typeReason) {
    return { ok: false, reason: typeReason };
  }

  onStage?.('reading');
  const size = await readActualSize(file);

  // Unknown size: send as picked; the server enforces the 3 MB limit.
  if (size === null || size <= AI_MAX_FILE_BYTES) {
    return { ok: true, file: size === null ? file : { ...file, size } };
  }

  switch (detectKind(file)) {
    case 'image':
      onStage?.('compressing');
      return compressImage(file, size);
    case 'pdf':
      onStage?.('optimizing');
      return optimizePdf(file, size);
    case 'docx':
      return {
        ok: false,
        reason: tooLarge(
          file.name,
          size,
          'Word documents cannot be reduced without changing them. Save it as a PDF and add that instead (large PDFs are optimized automatically), or remove large pictures from it.',
        ),
      };
    case 'text':
      return {
        ok: false,
        reason: tooLarge(
          file.name,
          size,
          'Text files are never altered, so it cannot be reduced. Split it into smaller files.',
        ),
      };
    default:
      return { ok: false, reason: `${file.name} is not a supported file type.` };
  }
}

export interface PrepareManyResult {
  ready: PickedFile[];
  rejections: string[];
}

// Prepares files one at a time, reporting which file is being worked on.
export async function prepareAiFiles(
  files: PickedFile[],
  onProgress?: (file: PickedFile, stage: PrepareStage) => void,
): Promise<PrepareManyResult> {
  const ready: PickedFile[] = [];
  const rejections: string[] = [];

  for (const file of files) {
    const outcome = await prepareAiFile(file, stage => onProgress?.(file, stage));
    if (outcome.ok) {
      ready.push(outcome.file);
    } else {
      rejections.push(outcome.reason);
    }
  }

  return { ready, rejections };
}

export const describeOptimization = (file: PickedFile): string | null => {
  if (!file.optimization || file.size === null) {
    return null;
  }
  const verb = file.optimization.method === 'compressed' ? 'Compressed' : 'Optimized';
  return `${verb} from ${formatFileSize(file.optimization.originalSize)} to ${formatFileSize(
    file.size,
  )}`;
};

export const stageLabel = (stage: PrepareStage): string =>
  stage === 'compressing'
    ? 'Compressing image...'
    : stage === 'optimizing'
    ? 'Optimizing PDF...'
    : 'Checking size...';
