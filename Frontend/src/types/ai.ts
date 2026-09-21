export type AiSessionStatus = 'processing' | 'extracted' | 'failed';

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
  message: string;
  percent: number;
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
  ocrQuality: string;
}

export interface AiParty {
  name: string;
  role: string;
}

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
  summary: string;
  parties: AiParty[];
  confidence: Record<string, number>;
  needsReview: string[];
}

export interface AiAnalyzeAccepted {
  sessionId: string;
  status: AiSessionStatus;
  progress: AiProgress;
  uploadedDocuments: AiUploadedDocument[];
  documentCount: number;
}

export interface AiSessionDetail {
  sessionId: string;
  status: AiSessionStatus;
  progress: AiProgress;
  extracted: AiExtractedData | null;
  uploadedDocuments: AiUploadedDocument[];
  voiceTranscript: string;
  voiceTranscriptLanguage: string;
  voiceTranscriptSource: 'none' | 'live' | 'server';
  voiceTranscriptionFailed: boolean;
  extractionWarnings: string[];
  failureReason: string;
  session?: unknown;
}

export interface PickedFile {
  uri: string;
  name: string;
  type: string | null;
  size: number | null;
  file?: unknown;
}
