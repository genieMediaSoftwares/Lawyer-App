/**
 * AI Smart Case Assistant contracts.
 *
 * Read from backend/src/models/AiSmartCaseSession.js,
 * controllers/ai/aiSmartCaseController.js and
 * services/ai/aiSmartCasePipeline.js.
 */

/** `AiSmartCaseSession.status` — exactly three values. */
export type AiSessionStatus = 'processing' | 'extracted' | 'failed';

/**
 * `PIPELINE_STAGES` ids, with their weights, from aiSmartCasePipeline.js:
 *
 *   queued        2   Preparing your documents
 *   ocr          50   Reading documents
 *   transcribing 12   Transcribing voice note
 *   extracting   28   Extracting case details
 *   classifying   8   Classifying the legal issue
 *   completed     0   Analysis complete
 *
 * Typed as a union plus `string` so a stage added server-side does not break
 * the client — the UI falls back to the server's own `message`.
 */
export type AiStage =
  | 'queued'
  | 'ocr'
  | 'transcribing'
  | 'extracting'
  | 'classifying'
  | 'completed'
  | 'failed'
  | (string & {});

export interface AiProgress {
  stage: AiStage;
  /** Written for display, e.g. "Reading document 2 of 5". Shown verbatim. */
  message: string;
  /** 0-100, derived from real stage weights server-side — never from a timer. */
  percent: number;
  /** Position within a repeated stage. Null outside one. */
  current: number | null;
  total: number | null;
  updatedAt: string;
}

export interface AiUploadedDocument {
  documentId: string | null;
  originalName: string;
  mimeType: string;
  size: number;
  url: string;
  documentType: string;
  /** "Pending" until the pipeline has read it. */
  ocrQuality: string;
}

/** One party the documents name. */
export interface AiParty {
  name: string;
  role: string;
}

/**
 * What the model extracted.
 *
 * Every field defaults to "" / null server-side, so an absent value is
 * indistinguishable from an empty one — the UI renders neither.
 */
export interface AiExtractedData {
  title: string;
  description: string;
  category: string;
  categoryId: string;
  subType: string;
  urgency: string;
  city: string;
  state: string;
  location: string;
  court: string;
  incidentDate: string | null;
  opposingParty: string;
  firNumber: string;
  policeStation: string;
  bailDetails: string;
  claimAmount: number | null;
  documentType: string;
  isCriminalLike: boolean;
  /** Neutral synopsis of what the AI understood. Distinct from `description`. */
  summary: string;
  parties: AiParty[];
  /** Per-field 0-1 confidence. Serialised from a Mongoose Map. */
  confidence: Record<string, number>;
  /** Fields the client should check — low confidence or degraded OCR. */
  needsReview: string[];
}

/** The `data` of POST /ai/smart-case/analyze — a 202, not a result. */
export interface AiAnalyzeAccepted {
  sessionId: string;
  status: AiSessionStatus;
  progress: AiProgress;
  uploadedDocuments: AiUploadedDocument[];
  documentCount: number;
}

/** The `data` of GET /ai/smart-case/session/:id. */
export interface AiSessionDetail {
  sessionId: string;
  status: AiSessionStatus;
  progress: AiProgress;
  extracted: AiExtractedData | null;
  uploadedDocuments: AiUploadedDocument[];
  voiceTranscript: string;
  /** "" | "en" | "hi" | "te" */
  voiceTranscriptLanguage: string;
  voiceTranscriptSource: 'none' | 'live' | 'server';
  voiceTranscriptionFailed: boolean;
  extractionWarnings: string[];
  /** Surfaced to the client verbatim by the backend. */
  failureReason: string;
  session?: unknown;
}

/** A file chosen on the device, normalised across platforms. */
export interface PickedFile {
  uri: string;
  name: string;
  /** May be null when the platform could not determine it. */
  type: string | null;
  size: number | null;
  /**
   * Web only. React Native's FormData takes `{uri, name, type}`, but on web
   * the real Blob has to be appended or the request body is the string
   * "[object Object]".
   */
  file?: unknown;
}
