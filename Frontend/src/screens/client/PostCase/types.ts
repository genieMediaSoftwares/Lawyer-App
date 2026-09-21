import type { AiParty, AiUploadedDocument } from '../../../types/ai';
import type {
  AppDocument,
  CreateCasePayload,
  RecommendedLawyer,
} from '../../../types/domain';
import { categoryById, categoryByTitle } from '../../../constants/categories';
import type { AiExtractedData } from '../../../types/ai';

/**
 * The Post Case flow's state.
 *
 * One object for all five steps, held by `PostCaseScreen` and handed down.
 * The steps are components rather than routes precisely so that moving back
 * and forward cannot lose anything the client typed — there is nothing to
 * unmount and remount.
 *
 * Field names follow `POST /cases`'s body where they map to it directly, so
 * `toCreatePayload` below is a rename-free copy and a field cannot drift away
 * from the name the server reads.
 */
export interface PostCaseState {
  // ── Step 1: category ────────────────────────────────────────────────────
  /** `LegalCategory.id`. Local only — the server stores the title. */
  categoryId: string;
  /** `Case.category`. */
  category: string;
  /** `Case.subcategory`. */
  subcategory: string;

  // ── Step 2: details ─────────────────────────────────────────────────────
  title: string;
  description: string;
  /** Shown as "City / Location"; sent as both `location` and `city`. */
  location: string;
  preferredCourt: string;
  urgency: string;

  // Structured detail. Only the AI populates these today — there is no field
  // for them on the form — but they are carried through to the payload and
  // shown on the review step so nothing extracted is quietly dropped.
  state: string;
  incidentDate: string | null;
  opposingParty: string;
  firNumber: string;
  policeStation: string;
  bailDetails: string;
  claimAmount: number | null;
  voiceTranscript: string;

  // ── Step 3: documents ───────────────────────────────────────────────────
  /** Which entry mode the client chose. Null until they pick one. */
  entryMode: EntryMode | null;
  /**
   * The manually uploaded acknowledgement, once it is stored server-side.
   *
   * The whole `AppDocument` rather than a subset, so the existing
   * `DocumentViewerModal` can render it without a second fetch.
   */
  document: AppDocument | null;
  /** The documents the AI read, as the session reported them. */
  aiDocuments: AiUploadedDocument[];

  // ── AI provenance ───────────────────────────────────────────────────────
  aiSessionId: string | null;
  /**
   * Which fields were filled by extraction and have not been edited since.
   *
   * Drives the "AI extracted" marker. A field leaves this set the moment the
   * client types in it, because from then on the value is theirs, not the
   * model's.
   */
  aiFields: string[];
  /** `extractedData.needsReview` — fields the server flagged as uncertain. */
  aiNeedsReview: string[];
  /** Per-document and coercion notes, shown verbatim. */
  aiWarnings: string[];
  /** The model's neutral synopsis. Read-only, never submitted as the description. */
  aiSummary: string;
  aiParties: AiParty[];
  /**
   * The extractor's description in full, before it was shortened.
   *
   * The form files a short, readable description, but the long version is kept
   * here so the client can put it back with one tap. Shortening that threw the
   * original away would quietly drop facts out of a legal filing, which is not
   * a trade this flow is entitled to make on their behalf.
   *
   * Empty when the extraction was already short enough to use as-is.
   */
  aiFullDescription: string;

  // ── Step 4: lawyer ──────────────────────────────────────────────────────
  /**
   * The chosen lawyer, in full.
   *
   * The whole recommendation row rather than just an id, so the review step
   * can show who is about to receive the case without fetching them again —
   * and so it shows exactly the figures that were on the card when the client
   * chose, rather than a second reading that may have moved.
   *
   * `selectedLawyer.userId` is the **User** id, which is what
   * `Case.selectedLawyer` references.
   */
  selectedLawyer: RecommendedLawyer | null;
}

export type EntryMode = 'manual' | 'ai';

/**
 * Roughly how long an auto-filled description should be before it stops being
 * something a lawyer skims and starts being something they scroll.
 */
const SHORT_DESCRIPTION_CHARS = 320;

/**
 * Shortens an extracted description to its opening sentences.
 *
 * Cuts only on sentence boundaries, never mid-sentence, so what remains still
 * reads as prose rather than a truncated fragment — and the full text is kept
 * on `aiFullDescription`, one tap away, because this is the text that actually
 * gets filed.
 *
 * Returns the input unchanged when it is already short enough, and when it
 * contains no sentence break to cut on — a single long sentence is left whole
 * rather than sliced at an arbitrary character.
 */
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
    // Each match carries the space that preceded it, so the pieces are
    // trimmed and rejoined with exactly one — otherwise every sentence break
    // in the result comes out doubled.
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

/** The five steps, in order. Labels are the stepper's. */
export const POST_CASE_STEPS = [
  'Category',
  'Details',
  'Documents',
  'Lawyers',
  'Review',
] as const;

export type PostCaseStepIndex = 0 | 1 | 2 | 3 | 4;

/**
 * Folds an extraction result into the form.
 *
 * Three rules, all of which exist to keep a guess out of a filed case:
 *
 *   1. **An empty extracted value never overwrites anything.** Every field on
 *      `extractedData` defaults to "" or null server-side, so an absent value
 *      and an empty one are indistinguishable — writing one through would
 *      erase something the client had typed.
 *   2. **A category is only taken when it resolves to a real taxonomy entry.**
 *      The server normalises the model's answer onto the same list, but if it
 *      could not, the step is left unselected rather than pre-filled with a
 *      title no dropdown contains.
 *   3. **A sub-type is only taken when it belongs to the chosen category.**
 *      Otherwise `Case.subcategory` would hold a value that category never
 *      offers.
 *
 * Every field it does fill is recorded in `aiFields`, which is what the
 * "AI extracted" markers read.
 */
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

  // Rule 2: resolve the category against the real taxonomy, by title first
  // and then by the id the extractor also returns.
  const resolved =
    categoryByTitle(extracted.category) || categoryById(extracted.categoryId);

  const category = resolved ? resolved.title : current.category;
  const categoryId = resolved ? resolved.id : current.categoryId;
  if (resolved) {
    filled.push('category');
  }

  // Rule 3: the sub-type has to be one this category actually offers.
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

  // Filed short, kept long. `aiFullDescription` holds the original only when
  // it was actually shortened, so the "full text" control knows whether it has
  // anything to offer.
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
    /**
     * The **city** first, then the model's free-form location string.
     *
     * That order matters for more than display. This one field is sent as the
     * payload's `city`, and `lawyerRecommendationService` matches it with
     * `userLocation.includes(city)` — so "Hyderabad" matches a lawyer in
     * "Hyderabad, Telangana" while the composite "Hyderabad, Telangana, India"
     * matches nobody. Taking the narrowest real value keeps matching working.
     * The state travels separately, in its own field.
     */
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

/**
 * Turns the form into the request body.
 *
 * The title falls back to the sub-type and then the category, which is what
 * the Details step's placeholder promises when it says the field can be left
 * blank. Nothing else is invented: an empty optional field is simply omitted.
 */
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
    // The form collects one place string. It is sent as both `location` (what
    // the lists display) and `city` (what lawyer matching reads), and the
    // state only when extraction supplied one — never split by guesswork.
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

/**
 * Whether a step is complete enough to leave.
 *
 * Step 3 accepts either entry mode: a stored acknowledgement, or a finished
 * analysis that read at least one document. Step 4 requires a lawyer because
 * the flow offers no other way forward — the server would accept a case
 * without one and notify every lawyer instead, which is a different product
 * decision than the one this screen presents.
 *
 * ── Why the sub-type is not required after an analysis ────────────────────
 *
 * Picking one by hand is required, because the category step offers them and a
 * half-made choice there is just an unfinished step. After an extraction it is
 * not, and requiring it was a real bug: the extractor frequently resolves a
 * category without producing a sub-type that matches one of the five allowed
 * strings exactly, and the flow then stopped on the category step instead of
 * going through to lawyer selection — the one thing the assistant exists to
 * save the client.
 *
 * Nothing downstream needs it. `createCase` stores `subcategory || ""`, and
 * `GET /lawyers/recommend` requires only `category` and treats `subcategory`
 * as an optional scoring bonus.
 */
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
