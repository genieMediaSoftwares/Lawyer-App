import type { AiParty, AiUploadedDocument } from '../../../types/ai';
import type {
  AppDocument,
  CreateCasePayload,
  RecommendedLawyer,
} from '../../../types/domain';
import { categoryById, categoryByTitle } from '../../../constants/categories';
import type { AiExtractedData } from '../../../types/ai';

export interface PostCaseState {
  categoryId: string;
  category: string;
  subcategory: string;

  title: string;
  description: string;
  location: string;
  preferredCourt: string;
  urgency: string;

  state: string;
  incidentDate: string | null;
  opposingParty: string;
  firNumber: string;
  policeStation: string;
  bailDetails: string;
  claimAmount: number | null;
  voiceTranscript: string;

  entryMode: EntryMode | null;
  document: AppDocument | null;
  aiDocuments: AiUploadedDocument[];

  aiSessionId: string | null;
  aiFields: string[];
  aiNeedsReview: string[];
  aiWarnings: string[];
  aiSummary: string;
  aiParties: AiParty[];
  aiFullDescription: string;

  selectedLawyer: RecommendedLawyer | null;
}

export type EntryMode = 'manual' | 'ai';

const SHORT_DESCRIPTION_CHARS = 320;

export const shortenDescription = (value: string): string => {
  const text = value.replace(/\s+/g, ' ').trim();

  if (text.length <= SHORT_DESCRIPTION_CHARS) {
    return text;
  }

  const sentences = text.match(/[^.!?]+[.!?]+/g);
  if (!sentences || sentences.length === 0) {
    return text;
  }

  let out = '';
  for (const sentence of sentences) {
    const piece = sentence.trim();
    const next = out ? `${out} ${piece}` : piece;

    if (out && next.length > SHORT_DESCRIPTION_CHARS) {
      break;
    }
    out = next;
  }

  return out || text;
};

export const initialPostCaseState: PostCaseState = {
  categoryId: '',
  category: '',
  subcategory: '',

  title: '',
  description: '',
  location: '',
  preferredCourt: '',
  urgency: '',

  state: '',
  incidentDate: null,
  opposingParty: '',
  firNumber: '',
  policeStation: '',
  bailDetails: '',
  claimAmount: null,
  voiceTranscript: '',

  entryMode: null,
  document: null,
  aiDocuments: [],

  aiSessionId: null,
  aiFields: [],
  aiNeedsReview: [],
  aiWarnings: [],
  aiSummary: '',
  aiParties: [],
  aiFullDescription: '',

  selectedLawyer: null,
};

export const POST_CASE_STEPS = [
  'Category',
  'Details',
  'Documents',
  'Lawyers',
  'Review',
] as const;

export type PostCaseStepIndex = 0 | 1 | 2 | 3 | 4;

export const applyExtraction = (
  current: PostCaseState,
  extracted: AiExtractedData,
  documents: AiUploadedDocument[],
  sessionId: string,
  voiceTranscript: string,
  warnings: string[],
): PostCaseState => {
  const filled: string[] = [];

  const take = (value: string, key: string, existing: string): string => {
    const trimmed = (value || '').trim();
    if (!trimmed) {
      return existing;
    }
    filled.push(key);
    return trimmed;
  };

  const resolved =
    categoryByTitle(extracted.category) || categoryById(extracted.categoryId);

  const category = resolved ? resolved.title : current.category;
  const categoryId = resolved ? resolved.id : current.categoryId;
  if (resolved) {
    filled.push('category');
  }

  const subType = (extracted.subType || '').trim();
  const subcategory =
    resolved && subType
      ? resolved.subTypes.find(
          s => s.toLowerCase() === subType.toLowerCase(),
        ) ?? current.subcategory
      : current.subcategory;
  if (subcategory && subcategory !== current.subcategory) {
    filled.push('subcategory');
  }

  const claimAmount =
    typeof extracted.claimAmount === 'number' && extracted.claimAmount > 0
      ? extracted.claimAmount
      : current.claimAmount;
  if (claimAmount !== current.claimAmount) {
    filled.push('claimAmount');
  }

  const incidentDate = extracted.incidentDate || current.incidentDate;
  if (incidentDate !== current.incidentDate) {
    filled.push('incidentDate');
  }

  const rawDescription = (extracted.description || '').trim();
  const shortDescription = shortenDescription(rawDescription);
  const wasShortened =
    Boolean(rawDescription) && shortDescription !== rawDescription;

  return {
    ...current,
    categoryId,
    category,
    subcategory,

    title: take(extracted.title, 'title', current.title),
    description: take(shortDescription, 'description', current.description),
    location: take(
      extracted.city || extracted.location,
      'location',
      current.location,
    ),
    preferredCourt: take(extracted.court, 'preferredCourt', current.preferredCourt),
    urgency: take(extracted.urgency, 'urgency', current.urgency),

    state: take(extracted.state, 'state', current.state),
    incidentDate,
    opposingParty: take(
      extracted.opposingParty,
      'opposingParty',
      current.opposingParty,
    ),
    firNumber: take(extracted.firNumber, 'firNumber', current.firNumber),
    policeStation: take(
      extracted.policeStation,
      'policeStation',
      current.policeStation,
    ),
    bailDetails: take(extracted.bailDetails, 'bailDetails', current.bailDetails),
    claimAmount,
    voiceTranscript: voiceTranscript || current.voiceTranscript,

    entryMode: 'ai',
    aiDocuments: documents,
    aiSessionId: sessionId,
    aiFields: Array.from(new Set(filled)),
    aiNeedsReview: extracted.needsReview ?? [],
    aiWarnings: warnings ?? [],
    aiSummary: (extracted.summary || '').trim(),
    aiParties: extracted.parties ?? [],
    aiFullDescription: wasShortened ? rawDescription : '',
  };
};

export const toCreatePayload = (state: PostCaseState): CreateCasePayload => {
  const title =
    state.title.trim() || state.subcategory.trim() || state.category.trim();

  const documents: CreateCasePayload['documents'] = [];
  if (state.document) {
    documents.push({
      name: state.document.name || state.document.originalName,
      url: state.document.filePath,
      size: String(state.document.fileSize ?? ''),
    });
  }
  for (const document of state.aiDocuments) {
    documents.push({
      name: document.originalName,
      url: document.url,
      size: String(document.size ?? ''),
    });
  }

  return {
    title,
    description: state.description.trim(),
    category: state.category,
    subcategory: state.subcategory || undefined,
    location: state.location.trim(),
    urgency: state.urgency || undefined,
    preferredCourt: state.preferredCourt.trim() || undefined,
    documents: documents.length > 0 ? documents : undefined,
    selectedLawyer: state.selectedLawyer?.userId || undefined,
    voiceTranscript: state.voiceTranscript || undefined,
    city: state.location.trim() || undefined,
    state: state.state.trim() || undefined,
    incidentDate: state.incidentDate || undefined,
    opposingParty: state.opposingParty.trim() || undefined,
    firNumber: state.firNumber.trim() || undefined,
    policeStation: state.policeStation.trim() || undefined,
    bailDetails: state.bailDetails.trim() || undefined,
    claimAmount: state.claimAmount ?? undefined,
  };
};

export const isStepComplete = (
  state: PostCaseState,
  step: PostCaseStepIndex,
): boolean => {
  switch (step) {
    case 0:
      return Boolean(
        state.category && (state.subcategory || state.aiSessionId),
      );
    case 1:
      return Boolean(state.description.trim() && state.location.trim());
    case 2:
      return Boolean(state.document || state.aiDocuments.length > 0);
    case 3:
      return Boolean(state.selectedLawyer);
    case 4:
      return true;
    default:
      return false;
  }
};
