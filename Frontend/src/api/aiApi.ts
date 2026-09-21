import { Platform } from 'react-native';

import { apiClient, unwrap } from './apiClient';
import { env } from '../config/env';
import { formatFileSize } from '../utils/format';
import type { ApiSuccess } from '../types/api';
import type {
  ResearchCase,
  ResearchCaseDocuments,
  ResearchConversation,
  ResearchSession,
} from '../types/lawyer';
import type {
  AiAnalyzeAccepted,
  AiSessionDetail,
  PickedFile,
} from '../types/ai';

const appendFile = (form: FormData, field: string, file: PickedFile): void => {
  if (Platform.OS === 'web' && file.file) {
    (form.append as (
      name: string,
      value: Blob,
      fileName?: string,
    ) => void)(field, file.file as Blob, file.name);
    return;
  }

  form.append(field, {
    uri: file.uri,
    name: file.name,
    type: file.type || 'application/octet-stream',
  } as unknown as Blob);
};

export interface AnalyzeInput {
  documents: PickedFile[];
  voice?: PickedFile | null;
  issueDescription?: string;
  voiceTranscript?: string;
  voiceLanguage?: string;
  requestId: string;
  onUploadProgress?: (fraction: number) => void;
}

export interface OptimizedDocument {
  token: string;
  name: string;
  mimeType: string;
  size: number;
  originalSize: number;
  optimized: boolean;
}

export interface AiChatInput {
  message: string;
  conversationId?: string;
  mode?: 'chat' | 'research';
}

export interface AiChatMessage {
  role: 'user' | 'model' | 'assistant';
  text: string;
  timestamp?: string;
}

export interface AiChatResponse {
  response: string;
  conversationId?: string;
  title?: string;
  messages?: AiChatMessage[];
}

export const aiApi = {
  async chat(input: AiChatInput): Promise<AiChatResponse> {
    const response = await apiClient.post<ApiSuccess<AiChatResponse>>(
      '/ai/chat',
      {
        message: input.message,
        conversationId: input.conversationId,
        mode: input.mode || 'chat',
      },
    );
    return unwrap(response);
  },

  async getResearchSessions(): Promise<ResearchSession[]> {
    const response = await apiClient.get<
      ApiSuccess<{ conversations: ResearchSession[] }>
    >('/ai/conversations', { params: { mode: 'research' } });
    return unwrap(response)?.conversations ?? [];
  },

  async getConversation(id: string): Promise<{
    id: string;
    title: string;
    messages: AiChatMessage[];
  }> {
    const response = await apiClient.get<
      ApiSuccess<{ conversation: { _id: string; title: string; messages: AiChatMessage[] } }>
    >(`/ai/conversations/${encodeURIComponent(id)}`);
    const conversation = unwrap(response)?.conversation;
    return {
      id: conversation?._id ?? id,
      title: conversation?.title ?? '',
      messages: conversation?.messages ?? [],
    };
  },

  async getResearchConversation(id: string): Promise<ResearchConversation> {
    const response = await apiClient.get<
      ApiSuccess<{ conversation: ResearchConversation }>
    >(`/ai/conversations/${encodeURIComponent(id)}`);
    return unwrap(response).conversation;
  },

  async getResearchCases(search?: string): Promise<ResearchCase[]> {
    const response = await apiClient.get<ApiSuccess<ResearchCase[]>>(
      '/ai/research/cases',
      { params: search ? { search } : undefined },
    );
    return unwrap(response) ?? [];
  },

  async getResearchCaseDocuments(caseId: string): Promise<ResearchCaseDocuments> {
    const response = await apiClient.get<ApiSuccess<ResearchCaseDocuments>>(
      `/ai/research/cases/${encodeURIComponent(caseId)}/documents`,
    );
    return unwrap(response);
  },

  async startCaseResearch(input: {
    caseId: string;
    documentIds: string[];
    question?: string;
    jurisdiction?: string;
  }): Promise<{ conversationId: string }> {
    const response = await apiClient.post<ApiSuccess<{ conversationId: string }>>(
      '/ai/research/sessions',
      input,
    );
    return unwrap(response);
  },

  async searchRelevantCases(
    conversationId: string,
    input: { query?: string; jurisdiction?: string } = {},
  ): Promise<void> {
    await apiClient.post(
      `/ai/research/${encodeURIComponent(conversationId)}/relevant-cases`,
      input,
    );
  },

  async deleteConversation(id: string): Promise<void> {
    await apiClient.delete(`/ai/conversations/${encodeURIComponent(id)}`);
  },

  async transcribe(
    audio: PickedFile,
    language?: string,
  ): Promise<{ transcript: string; language: string }> {
    const form = new FormData();
    appendFile(form, 'audio', audio);
    if (language) {
      form.append('language', language);
    }

    const response = await apiClient.post<
      ApiSuccess<{ transcript: string; language: string }>
    >('/ai/transcribe', form, {
      headers: { 'Content-Type': undefined },
      timeout: 120000,
    });

    return unwrap(response);
  },

  async analyze(input: AnalyzeInput): Promise<AiAnalyzeAccepted> {
    const tooLarge = uploadTooLargeReason([...input.documents, input.voice]);
    if (tooLarge) {
      throw new Error(tooLarge);
    }

    const form = new FormData();

    for (const document of input.documents) {
      if (document.preparedToken) {
        form.append('preparedDocuments', document.preparedToken);
      } else {
        appendFile(form, 'documents', document);
      }
    }

    if (input.voice) {
      appendFile(form, 'voice', input.voice);
    }

    if (input.issueDescription?.trim()) {
      form.append('issueDescription', input.issueDescription.trim());
    }
    if (input.voiceTranscript?.trim()) {
      form.append('voiceTranscript', input.voiceTranscript.trim());
    }
    if (input.voiceLanguage) {
      form.append('voiceLanguage', input.voiceLanguage);
    }

    form.append('requestId', input.requestId);

    const response = await apiClient.post<ApiSuccess<AiAnalyzeAccepted>>(
      '/ai/smart-case/analyze',
      form,
      {
        headers: { 'Content-Type': undefined },
        timeout: 180000,
        onUploadProgress: event => {
          if (input.onUploadProgress && event.total) {
            input.onUploadProgress(
              Math.min(1, event.loaded / event.total),
            );
          }
        },
      },
    );

    return unwrap(response);
  },

  // Sends a PDF over 3 MB to be shrunk server-side. The result is held on the
  // server and later included in the analysis by its token.
  async optimizePdf(
    file: PickedFile,
    onUploadProgress?: (fraction: number) => void,
  ): Promise<OptimizedDocument> {
    const form = new FormData();
    appendFile(form, 'document', file);

    const response = await apiClient.post<ApiSuccess<OptimizedDocument>>(
      '/ai/smart-case/optimize',
      form,
      {
        headers: { 'Content-Type': undefined },
        timeout: 240000,
        onUploadProgress: event => {
          if (onUploadProgress && event.total) {
            onUploadProgress(Math.min(1, event.loaded / event.total));
          }
        },
      },
    );
    return unwrap(response);
  },

  async getSession(sessionId: string): Promise<AiSessionDetail> {
    const response = await apiClient.get<ApiSuccess<AiSessionDetail>>(
      `/ai/smart-case/session/${encodeURIComponent(sessionId)}`,
    );
    return unwrap(response);
  },

  async getHistory(limit = 20): Promise<unknown[]> {
    const response = await apiClient.get<ApiSuccess<unknown[]>>(
      '/ai/smart-case/history',
      { params: { limit: String(limit) } },
    );
    return unwrap(response) ?? [];
  },

  async linkCase(sessionId: string, caseId: string): Promise<void> {
    await apiClient.post<ApiSuccess<unknown>>(
      `/ai/smart-case/session/${encodeURIComponent(sessionId)}/link-case`,
      { caseId },
    );
  },
};

export const UPLOAD_LIMITS = {
  maxDocuments: 10,
  maxFileBytes: 10 * 1024 * 1024,
  documentMimeTypes: [
    'application/pdf',
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'text/plain',
    'text/markdown',
    'text/csv',
  ],
  documentExtensions: ['.pdf', '.jpg', '.jpeg', '.png', '.webp', '.docx', '.txt', '.md', '.csv'],
  audioMimeTypes: [
    'audio/mpeg',
    'audio/mp3',
    'audio/wav',
    'audio/m4a',
    'audio/x-m4a',
    'audio/mp4',
    'audio/webm',
    'audio/ogg',
    'audio/aac',
    'audio/3gpp',
    'audio/amr',
  ],
} as const;

// AI Smart Case Assistant: the largest document accepted as-is. Anything larger
// is optimized automatically before upload (see services/aiFileOptimizer).
export const AI_MAX_FILE_BYTES = 3 * 1024 * 1024;

export const maxAiUploadBytes = (): number | null =>
  env.aiUploadMaxMb === null ? null : Math.floor(env.aiUploadMaxMb * 1024 * 1024);

export const maxAiFileBytes = (): number => {
  const total = maxAiUploadBytes();
  return total === null ? UPLOAD_LIMITS.maxFileBytes : Math.min(UPLOAD_LIMITS.maxFileBytes, total);
};

// Bytes the analysis request itself will carry. PDFs optimized on the server
// are already there and travel only as a token.
export const knownTotalBytes = (files: ReadonlyArray<PickedFile | null | undefined>): number =>
  files.reduce((sum, file) => sum + (file && !file.preparedToken ? file.size ?? 0 : 0), 0);

export const uploadTooLargeReason = (
  files: ReadonlyArray<PickedFile | null | undefined>,
): string | null => {
  const max = maxAiUploadBytes();
  const total = knownTotalBytes(files);
  if (max === null || total <= max) {
    return null;
  }
  return `Your files add up to ${formatFileSize(total)}, but one upload can be at most ${formatFileSize(
    max,
  )}. Please remove a file or reduce the file sizes (for example, compress the PDF or scan at a lower resolution), then try again.`;
};

export const rejectionReasonFor = (file: PickedFile): string | null => {
  const maxBytes = maxAiFileBytes();
  if (file.size !== null && file.size > maxBytes) {
    return `${file.name} is ${formatFileSize(file.size)}, over the ${formatFileSize(
      maxBytes,
    )} limit. Please reduce or compress it and try again.`;
  }

  return unsupportedTypeReason(file);
};

export const unsupportedTypeReason = (file: PickedFile): string | null => {
  const name = file.name.toLowerCase();

  if (name.endsWith('.doc')) {
    return `${file.name} is an older .doc file, which cannot be read. Please save it as PDF or .docx.`;
  }

  const extensionAllowed = UPLOAD_LIMITS.documentExtensions.some(extension =>
    name.endsWith(extension),
  );
  const mimeAllowed =
    file.type !== null &&
    (UPLOAD_LIMITS.documentMimeTypes as readonly string[]).includes(file.type);

  if (!extensionAllowed && !mimeAllowed) {
    return `${file.name} is not a supported file type.`;
  }

  return null;
};
