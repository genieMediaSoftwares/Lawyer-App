import type { PickedFile } from '../types/ai';

/**
 * Voice-note recording in a browser, via MediaRecorder.
 *
 * No dependency: MediaRecorder and getUserMedia are platform APIs. The catch
 * is the container — Chrome and Firefox record **webm/opus**, Safari records
 * **mp4/aac** — so the type is chosen from what the browser reports it can
 * produce, and checked against the backend's allowlist before recording
 * starts. `audio/webm` and `audio/mp4` are both on it
 * (upload.middleware.js maps them to `.webm` and `.m4a`).
 *
 * `isSupported` is false on a browser without MediaRecorder, or on an insecure
 * origin where getUserMedia is unavailable. The UI hides the control rather
 * than offering a button that cannot work.
 */

export interface RecordingState {
  durationMs: number;
}

/** In preference order, filtered by what this browser can actually encode. */
const CANDIDATE_TYPES = [
  'audio/webm;codecs=opus',
  'audio/webm',
  'audio/mp4',
  'audio/ogg;codecs=opus',
  'audio/ogg',
];

/** The MIME the backend is told, stripped of codec parameters. */
const baseMime = (type: string): string => type.split(';')[0];

const pickMimeType = (): string | null => {
  if (typeof MediaRecorder === 'undefined') {
    return null;
  }

  for (const candidate of CANDIDATE_TYPES) {
    if (MediaRecorder.isTypeSupported(candidate)) {
      return candidate;
    }
  }

  return null;
};

const EXTENSION_BY_MIME: Record<string, string> = {
  'audio/webm': '.webm',
  'audio/mp4': '.m4a',
  'audio/ogg': '.ogg',
};

let recorder: MediaRecorder | null = null;
let stream: MediaStream | null = null;
let chunks: Blob[] = [];
let ticker: ReturnType<typeof setInterval> | null = null;

/** Releases the microphone. Leaving the track live keeps the browser's
 *  recording indicator on, which is alarming and rightly so. */
const releaseStream = () => {
  stream?.getTracks().forEach(track => track.stop());
  stream = null;
};

const stopTicker = () => {
  if (ticker) {
    clearInterval(ticker);
    ticker = null;
  }
};

export const voiceRecorder = {
  isSupported:
    typeof navigator !== 'undefined' &&
    typeof navigator.mediaDevices?.getUserMedia === 'function' &&
    typeof MediaRecorder !== 'undefined' &&
    pickMimeType() !== null,

  /**
   * Asking for the stream *is* the permission prompt in a browser, so this
   * requests it and releases it again rather than holding the microphone open
   * between the prompt and the first recording.
   */
  async requestPermission(): Promise<boolean> {
    try {
      const probe = await navigator.mediaDevices.getUserMedia({ audio: true });
      probe.getTracks().forEach(track => track.stop());
      return true;
    } catch {
      return false;
    }
  },

  async start(onTick: (state: RecordingState) => void): Promise<void> {
    const mimeType = pickMimeType();
    if (!mimeType) {
      throw new Error('This browser cannot record audio.');
    }

    stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    chunks = [];

    recorder = new MediaRecorder(stream, { mimeType });
    recorder.addEventListener('dataavailable', event => {
      if (event.data.size > 0) {
        chunks.push(event.data);
      }
    });

    // 250ms slices, so a tab closed mid-recording still leaves usable audio
    // rather than one buffer that was never flushed.
    recorder.start(250);

    const startedAt = Date.now();
    ticker = setInterval(
      () => onTick({ durationMs: Date.now() - startedAt }),
      100,
    );
  },

  async stop(): Promise<PickedFile> {
    stopTicker();

    const active = recorder;
    if (!active) {
      throw new Error('Not recording.');
    }

    const mimeType = baseMime(active.mimeType || 'audio/webm');

    const blob = await new Promise<Blob>(resolve => {
      active.addEventListener(
        'stop',
        () => resolve(new Blob(chunks, { type: mimeType })),
        { once: true },
      );
      active.stop();
    });

    releaseStream();
    recorder = null;

    const extension = EXTENSION_BY_MIME[mimeType] ?? '.webm';
    const name = `genie-voice-note${extension}`;

    return {
      uri: '',
      name,
      type: mimeType,
      size: blob.size,
      // The browser's FormData needs the Blob itself — see aiApi.appendFile.
      file: new File([blob], name, { type: mimeType }),
    };
  },

  async cancel(): Promise<void> {
    stopTicker();
    try {
      recorder?.stop();
    } catch {
      // Already stopped. Nothing to undo.
    }
    releaseStream();
    recorder = null;
    chunks = [];
  },
};
