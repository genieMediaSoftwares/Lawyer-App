/**
 * Domain types, read off the backend's Mongoose models and controllers.
 *
 * Every field here exists on the server. Nothing is aspirational: a property
 * the backend does not send is not declared, so a screen cannot render it and
 * then quietly show `undefined`.
 *
 * Sources:
 *   backend/src/models/Case.js
 *   backend/src/models/Lawyer.js
 *   backend/src/models/Client.js
 *   backend/src/models/Notification.js
 *   backend/src/models/Document.js
 *   backend/src/controllers/**
 */

import type { UserRole } from './auth';

// ---------------------------------------------------------------------------
// Shared
// ---------------------------------------------------------------------------

/**
 * A User as it arrives embedded in another document.
 *
 * Mongoose `populate` selects a subset, and the subset differs per call site —
 * `getCases` asks for `fullName email mobile profileImage`, `getAllLawyers`
 * also takes `location isVerified isActive`. Everything past the first four is
 * therefore optional.
 */
export interface PopulatedUser {
  _id: string;
  fullName: string;
  email: string;
  mobile: string;
  profileImage: string;
  location?: string;
  isVerified?: boolean;
  isActive?: boolean;
  role?: UserRole;
}

// ---------------------------------------------------------------------------
// Cases
// ---------------------------------------------------------------------------

/**
 * The status enum on backend/src/models/Case.js, exactly.
 *
 * Eight values, not the four a progress tracker would like. The UI groups them
 * rather than inventing a parallel vocabulary — see `CASE_STAGE` in
 * src/constants/cases.ts.
 */
export const CASE_STATUSES = [
  'Submitted',
  'Awaiting Lawyer Acceptance',
  'Pending Lawyer Response',
  'Interested',
  'Accepted',
  'In Progress',
  'Closed',
  'Rejected',
] as const;

export type CaseStatus = (typeof CASE_STATUSES)[number];

/** Embedded document on a Case. Note `size` is a string, not a number. */
export interface CaseDocument {
  name: string;
  url: string;
  size: string;
}

export interface CaseMilestone {
  _id?: string;
  title: string;
  date: string;
  isCompleted: boolean;
}

export type HearingStatus =
  | 'scheduled'
  | 'completed'
  | 'adjourned'
  | 'cancelled';

export interface CaseHearing {
  _id: string;
  date: string;
  /** Free text — "10:30 AM", "Item 42". Courts do not publish precise slots. */
  timeSlot: string;
  court: string;
  purpose: string;
  status: HearingStatus;
  notes: string;
  createdAt: string;
}

export interface CaseProposal {
  _id?: string;
  lawyer: PopulatedUser | null;
  feeProposal: number;
  message: string;
  createdAt: string;
}

/**
 * A case.
 *
 * `selectedLawyerProfile` and `assignedLawyerProfile` are not schema fields —
 * the controller attaches them after the query by looking up the Lawyer
 * document for each populated user. They are absent when no lawyer is set.
 */
export interface LegalCase {
  _id: string;
  client: PopulatedUser | string;
  title: string;
  description: string;
  category: string;
  subcategory: string;

  location: string;
  locationCity: string;
  locationDistrict: string;
  locationState: string;
  locationCountry: string;
  locationPlaceId: string;
  locationLatitude: number;
  locationLongitude: number;

  preferredCourt: string;

  incidentDate: string | null;
  opposingParty: string;
  firNumber: string;
  policeStation: string;
  bailDetails: string;

  budgetRange: string;
  urgency: string;
  status: CaseStatus;

  documents: CaseDocument[];
  proposals: CaseProposal[];

  selectedLawyer: PopulatedUser | null;
  assignedLawyer: PopulatedUser | null;
  /** Injected by the controller, not stored on the Case. */
  selectedLawyerProfile?: LawyerProfile | null;
  assignedLawyerProfile?: LawyerProfile | null;

  milestones: CaseMilestone[];
  hearings: CaseHearing[];

  caseOutcome: string;
  claimAmount: string;
  consultationDate: string | null;
  nextHearing: string | null;
  closedDate: string | null;

  rating: number;
  review: string;

  acceptedAt: string | null;
  startedAt: string | null;
  completedAt: string | null;

  voiceUrl: string;
  voiceTranscript: string;

  createdAt: string;
  updatedAt: string;
}

// ---------------------------------------------------------------------------
// Lawyers / Advocates
// ---------------------------------------------------------------------------

/**
 * A Lawyer profile document, with its `user` populated.
 *
 * `rating`, `totalReviews`, `casesHandled` and `winPercentage` are real schema
 * fields, but a freshly created profile leaves them at zero. A zero is
 * displayed as "no rating yet", never rounded up into a plausible-looking
 * number — see §5 and the `GenieEmptyState` treatment on the profile screen.
 */
export interface LawyerProfile {
  _id: string;
  user: PopulatedUser | null;
  specialization: string;
  experience: number;
  education: string;
  barCouncilNumber: string;
  languages: string[];
  consultationFee: number;
  bio: string;
  officeAddress: string;
  availability?: string[];
  rating: number;
  totalReviews: number;
  verificationStatus?: string;
  workingHours?: string;
  casesHandled?: number;
  winPercentage?: number;
  responseTime?: string;
  district?: string;
  practiceAreas?: string[];
  createdAt: string;
  updatedAt: string;
}

/**
 * One row of `GET /lawyers/recommend`.
 *
 * Deliberately **not** a `LawyerProfile`. That endpoint does not return Lawyer
 * documents: `services/lawyer/lawyerRecommendationService.js` builds a flat
 * projection with the user's fields hoisted to the top level, so there is no
 * `user` object to read `fullName` from and the id fields are split in two.
 *
 * `matchPercentage` is the server's own weighted score (location, speciality,
 * rating, experience, verified). It is displayed as given and never
 * recomputed here.
 */
export interface RecommendedLawyer {
  /** The Lawyer document id. */
  lawyerId: string;
  /** The User id — what `GET /lawyers/:id` and `Case.selectedLawyer` want. */
  userId: string;
  fullName: string;
  profileImage: string;
  specialization: string;
  city: string;
  district: string;
  state: string;
  location: string;
  experience: number;
  rating: number;
  reviewCount: number;
  consultationFee: number;
  languages: string[];
  practiceAreas: string[];
  verified: boolean;
  onlineStatus: boolean;
  responseTime: string;
  /** 65-98, capped server-side. */
  matchPercentage: number;
  casesHandled: number;
  winPercentage: number;
  locationScore: number;
  bio: string;
  education: string;
  barCouncilNumber: string;
  officeAddress: string;
  workingHours: string;
}

/**
 * The body of `POST /cases`, matching exactly what `createCase` destructures.
 *
 * Anything absent here is ignored by the controller, and anything the
 * controller reads is listed here — so a field cannot be sent hopefully and
 * silently dropped.
 */
export interface CreateCasePayload {
  title: string;
  description: string;
  category: string;
  subcategory?: string;
  location: string;
  budgetRange?: string;
  urgency?: string;
  preferredCourt?: string;
  /** `Case.documents` is `{name, url, size}` — all three are strings. */
  documents?: { name: string; url: string; size: string }[];
  /** A **User** id. Present means "Awaiting Lawyer Acceptance", absent means
   *  "Submitted" and every lawyer is notified. */
  selectedLawyer?: string;
  voiceUrl?: string;
  voiceTranscript?: string;
  city?: string;
  district?: string;
  state?: string;
  country?: string;
  latitude?: number;
  longitude?: number;
  placeId?: string;

  // Structured detail, AI-extracted then client-edited. All optional.
  incidentDate?: string | null;
  opposingParty?: string;
  firNumber?: string;
  policeStation?: string;
  bailDetails?: string;
  claimAmount?: number | null;
}

// ---------------------------------------------------------------------------
// Favorites
// ---------------------------------------------------------------------------

/**
 * One row of GET /favorites.
 *
 * `lawyer` is the User (a Favorite refs User, not Lawyer), and `profile` is the
 * matching Lawyer document, which the controller looks up separately and may
 * legitimately return as null.
 */
export interface FavoriteEntry {
  _id: string;
  lawyer: PopulatedUser | null;
  profile: LawyerProfile | null;
}

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

export type NotificationPriority = 'low' | 'medium' | 'high';

export interface AppNotification {
  _id: string;
  notificationId?: string;
  senderId: Pick<PopulatedUser, '_id' | 'fullName' | 'profileImage'> & {
    role?: UserRole;
  } | null;
  receiverId: string;
  title: string;
  message: string;
  /** Free-form on the client: the backend enum is long and append-only. */
  type: string;
  priority: NotificationPriority;
  metadata?: Record<string, unknown>;
  referenceId?: string;
  isRead: boolean;
  createdAt: string;
}

/** The pagination envelope GET /notifications wraps its list in. */
export interface PageInfo {
  total: number;
  page: number;
  limit: number;
  pages: number;
}

export interface NotificationPage {
  notifications: AppNotification[];
  pagination: PageInfo;
  unreadCount: number;
}

// ---------------------------------------------------------------------------
// Client profile
// ---------------------------------------------------------------------------

/** The Client side-document. Created on first read if absent. */
export interface ClientProfileDoc {
  _id: string;
  user: string;
  createdAt?: string;
  updatedAt?: string;
  [key: string]: unknown;
}

export interface ClientProfileResponse {
  user: ProfileUserDoc;
  profile: ClientProfileDoc;
}

/** `User.findById().select('-password')` — the raw document, so `_id`. */
export interface ProfileUserDoc {
  _id: string;
  fullName: string;
  email: string;
  mobile: string;
  role: UserRole;
  profileImage: string;
  location: string;
  dob: string;
  gender: string;
  languages: string[];
  isVerified: boolean;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

/** GET /client/stats — four real counts, computed server-side. */
export interface ClientStats {
  activeCases: number;
  totalCases: number;
  totalAppointments: number;
  totalDocuments: number;
}

// ---------------------------------------------------------------------------
// Chat & Messages
// ---------------------------------------------------------------------------

export interface MessageAttachment {
  name: string;
  url: string;
  mimeType?: string;
  size?: number;
}

export interface ChatMessage {
  _id: string;
  chat: string;
  sender: PopulatedUser | string;
  content: string;
  attachments?: MessageAttachment[];
  clientId?: string;
  isRead: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface ChatConversation {
  _id: string;
  participants: (PopulatedUser & { specialization?: string })[];
  lastMessage?: string;
  lastMessageAt?: string;
  lastMessageSender?: string;
  unreadCount?: number;
  caseInfo?: {
    id: string;
    title: string;
  } | null;
  createdAt: string;
  updatedAt: string;
}

// ---------------------------------------------------------------------------
// Documents
// ---------------------------------------------------------------------------

export interface AppDocument {
  _id: string;
  clientId: string;
  issueId?: string | null;
  originalName: string;
  name?: string;
  fileName: string;
  filePath: string;
  mimeType: string;
  fileSize: number;
  uploadedAt: string;
  createdAt: string;
  updatedAt: string;
}
