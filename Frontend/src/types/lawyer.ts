/**
 * The shapes the lawyer-side endpoints actually return.
 *
 * Every type here was read off backend/src/controllers/lawyer/lawyerController.js,
 * caseController.js, appointmentController.js and the Lawyer model — not
 * inferred from what the screens would like to show. Where a screen wants a
 * field the backend does not send, the field is absent here and the screen
 * goes without it rather than inventing a value.
 */

import type { PopulatedUser } from './domain';

/**
 * One row of `GET /lawyers/leads`.
 *
 * The controller hand-builds this object; it is NOT a Case document. A lead is
 * either a case where this lawyer is the `selectedLawyer` and awaiting their
 * answer, or an unclaimed case with status "Submitted".
 */
export interface LawyerLead {
  caseId: string;
  clientName: string;
  clientProfileImage?: string;
  clientLocation?: string;
  issueCategory: string;
  issueTitle: string;
  location: string;
  /** ISO date — the case's createdAt. */
  postedTime: string;
  urgency: string;
  documentsCount?: number;
  /** URL of the first attached document, or "" when there are none. */
  acknowledgementDocument: string;
  preferredCourt: string;
  caseStatus: string;
  matchPercentage?: number | null;
}

/**
 * One row of `GET /lawyers/clients`.
 */
export interface LawyerClientRow {
  clientId: string;
  name: string;
  profileImage: string;
  caseId: string;
  /** The case title. */
  issue: string;
  category?: string;
  location?: string;
  preferredCourt?: string;
  currentStatus: string;
  acceptedAt?: string;
  /** ISO date — the case's updatedAt. */
  lastActivity: string;
  tasksRemaining?: number;
}

/**
 * `GET /lawyers/clients` groups its own rows. The three keys map onto the
 * three tabs; the grouping is the backend's, not ours.
 *
 *   accepted   — status "Awaiting Lawyer Acceptance" or "Submitted"
 *   inProgress — status "In Progress"
 *   closed     — status "Closed"
 */
export interface LawyerClientGroups {
  accepted: LawyerClientRow[];
  inProgress: LawyerClientRow[];
  closed: LawyerClientRow[];
}

export type ScheduleEventType =
  | 'consultation'
  | 'hearing'
  | 'meeting'
  | 'reminder';

/**
 * One entry of `GET /lawyers/schedule/today`.
 *
 * Merged server-side from three sources — appointments, case hearings and
 * calendar events — and sorted by start time. `client` and `case` are empty
 * strings for calendar events, which belong to no one.
 */
export interface LawyerScheduleEvent {
  title: string;
  client: string;
  case: string;
  startTime: string;
  endTime: string;
  eventType: ScheduleEventType;
}

/** `GET /lawyers/messages/unread`. */
export interface LawyerUnreadMessages {
  unreadCount: number;
  conversationCount: number;
  latestMessage: string;
  latestClient: string;
  lastMessageTime: string | null;
}

export type LawyerVerificationStatus = 'pending' | 'verified' | 'rejected';

/**
 * `GET /lawyers/:id` — the Lawyer document with `user` populated.
 *
 * The numeric track-record fields all default to 0 in the schema, and the
 * model comments are explicit that this is deliberate: they must read as "not
 * provided" rather than as a flattering placeholder. The UI honours that by
 * hiding a stat that is zero instead of printing "0%".
 *
 * There is no profile-completion percentage anywhere in the backend, so the
 * profile screen does not show one.
 */
export interface LawyerProfileDetail {
  _id: string;
  user: PopulatedUser;
  specialization: string;
  experience: number;
  education: string;
  barCouncilNumber: string;
  languages: string[];
  consultationFee: number;
  bio: string;
  officeAddress: string;
  rating: number;
  totalReviews: number;
  verificationStatus: LawyerVerificationStatus;
  subscriptionPlan: string;
  workingHours: string;
  casesHandled: number;
  winPercentage: number;
  responseTime: string;
  district: string;
  practiceAreas: string[];
  createdAt: string;
  updatedAt: string;
}

/** The fields `PUT /lawyers/profile` destructures. Anything else is ignored. */
export interface LawyerProfileUpdate {
  specialization?: string;
  experience?: number;
  education?: string;
  barCouncilNumber?: string;
  consultationFee?: number;
  bio?: string;
  officeAddress?: string;
  workingHours?: string;
}

export type AppointmentStatus =
  | 'pending'
  | 'confirmed'
  | 'completed'
  | 'cancelled';

/**
 * `GET /appointments`, scoped to the signed-in user by role — a lawyer gets
 * `{lawyer: req.user._id}` and can never see another lawyer's diary.
 */
export interface Appointment {
  _id: string;
  client: PopulatedUser | null;
  lawyer: PopulatedUser | null;
  case: { _id: string; title: string; category: string } | null;
  date: string;
  timeSlot: string;
  mode: 'Chat' | 'In-Person';
  status: AppointmentStatus;
  meetingLink: string;
  notes: string;
  createdAt: string;
  updatedAt: string;
}

/** One row of `GET /cases/hearings/mine` — a hearing flattened with its case. */
export interface LawyerHearing {
  _id?: string;
  date: string;
  timeSlot?: string;
  court?: string;
  purpose?: string;
  status?: string;
  /** Outcome or preparation notes. Carries the case's visibility, not private. */
  notes?: string;
  createdAt?: string;
  updatedAt?: string;
  caseId: string;
  caseTitle: string;
  caseCategory: string;
  caseStatus: string;
  clientId: string | null;
  clientName: string;
  clientImage: string;
}

/**
 * `GET /subscription`.
 *
 * When there is no active subscription row the controller synthesises a Free
 * plan rather than 404ing, so this always resolves.
 */
export interface SubscriptionInfo {
  plan: string;
  status: string;
  startDate: string;
  endDate: string;
}

/**
 * One note from `GET /clients/:id/notes`.
 *
 * A subdocument of `Client.notes`, not its own collection — which is why a
 * note is always addressed through the client it belongs to. The controller
 * filters the array to notes authored by the signed-in lawyer before it
 * returns, so this can never contain another advocate's note.
 *
 * `case` is the only optional relation the model carries. There are no tags
 * and no category — those are not fields on the schema.
 */
export interface LawyerNote {
  _id: string;
  title: string;
  text: string;
  /** A Case id, or null when the note is filed against the client generally. */
  case: string | null;
  /** Populated as `{_id, fullName, profileImage}` by `getNotes`. */
  lawyer: { _id: string; fullName?: string; profileImage?: string } | string;
  date: string;
  updatedAt: string;
}

/**
 * A note as the list screen holds it: the note plus which client it hangs off.
 *
 * The endpoint is per-client, so the workspace fetches each client's notes and
 * keeps the owning client with each one — without it there would be no way to
 * address the note again for an edit or a delete.
 */
export interface LawyerNoteRow extends LawyerNote {
  clientId: string;
  clientName: string;
}

/** The body of `POST`/`PUT /clients/:id/notes`. Exactly what it destructures. */
export interface LawyerNoteInput {
  /** Required — the controller 400s on an empty one. */
  text: string;
  title?: string;
  /** Must be a case of this client that this lawyer is on, or the API 404s. */
  caseId?: string | null;
}

/** `Case.hearings[].status` — the schema enum, in full. */
export type HearingStatus =
  | 'scheduled'
  | 'completed'
  | 'adjourned'
  | 'cancelled';

/**
 * The body of `POST /cases/:id/hearings` and `PUT /cases/:id/hearings/:hearingId`.
 *
 * `date` is the only required field. `timeSlot` and `court` are free text by
 * design — see the Case model's own comments: courts do not publish precise
 * slots, and a hearing must be recordable at a bench missing from the seeded
 * Court directory.
 */
export interface HearingInput {
  date: string;
  timeSlot?: string;
  court?: string;
  purpose?: string;
  status?: HearingStatus;
  notes?: string;
}

/** One research conversation from `GET /ai/conversations?mode=research`. */
export interface ResearchSession {
  id: string;
  title: string;
  lastMessage: string;
  createdAt: string;
  updatedAt: string;
  messageCount: number;
}
