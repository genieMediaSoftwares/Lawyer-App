import { apiClient, unwrap } from './apiClient';
import type { ApiSuccess } from '../types/api';
import type {
  Appointment,
  HearingInput,
  LawyerNote,
  LawyerNoteInput,
  LawyerClientGroups,
  LawyerHearing,
  LawyerLead,
  LawyerProfileDetail,
  LawyerProfileUpdate,
  LawyerScheduleEvent,
  LawyerUnreadMessages,
  SubscriptionInfo,
} from '../types/lawyer';

/**
 * The lawyer-side endpoints, from backend/src/routes/lawyer.routes.js,
 * case.routes.js, appointment.routes.js and subscription.routes.js.
 *
 * ── What the backend does NOT have ────────────────────────────────────────
 *
 * Deliberately absent, because no route exists and none is invented here:
 *
 *   - Legal research. Nothing in backend/src/routes serves it.
 *   - A standalone notes store. Notes exist only per client, at
 *     `/clients/:id/notes`, scoped to the authoring lawyer.
 *   - A profile-completion percentage. Not a field on the Lawyer model.
 *
 * ── Authorisation ─────────────────────────────────────────────────────────
 *
 * Every route below sits behind `authMiddleware` and scopes to `req.user._id`
 * server-side: leads match on `selectedLawyer`, clients on `assignedLawyer`,
 * appointments on `{lawyer: req.user._id}`, hearings 403 for any non-lawyer.
 * Nothing here can be made to return another lawyer's data by passing a
 * different id, and nothing tries.
 */
export const lawyerApi = {
  /**
   * GET /lawyers/leads
   *
   * Cases awaiting this lawyer's answer, plus unclaimed "Submitted" cases.
   * Returns a hand-built projection, not Case documents.
   */
  async getLeads(): Promise<LawyerLead[]> {
    const response = await apiClient.get<ApiSuccess<LawyerLead[]>>(
      '/lawyers/leads',
    );
    return unwrap(response) ?? [];
  },

  /**
   * GET /lawyers/clients
   *
   * Already grouped by the backend into accepted / inProgress / closed. The
   * three tabs read those keys directly rather than re-deriving them, so the
   * grouping cannot drift from the server's.
   */
  async getClients(): Promise<LawyerClientGroups> {
    const response = await apiClient.get<ApiSuccess<LawyerClientGroups>>(
      '/lawyers/clients',
    );
    return (
      unwrap(response) ?? { accepted: [], inProgress: [], closed: [] }
    );
  },

  /** GET /lawyers/schedule/today — appointments, hearings and events merged. */
  async getScheduleToday(): Promise<LawyerScheduleEvent[]> {
    const response = await apiClient.get<ApiSuccess<LawyerScheduleEvent[]>>(
      '/lawyers/schedule/today',
    );
    return unwrap(response) ?? [];
  },

  /** GET /lawyers/messages/unread — counts plus the most recent message. */
  async getUnreadMessages(): Promise<LawyerUnreadMessages> {
    const response = await apiClient.get<ApiSuccess<LawyerUnreadMessages>>(
      '/lawyers/messages/unread',
    );
    return (
      unwrap(response) ?? {
        unreadCount: 0,
        conversationCount: 0,
        latestMessage: '',
        latestClient: '',
        lastMessageTime: null,
      }
    );
  },

  /**
   * GET /lawyers/:id
   *
   * The id is a **user** id — the controller looks up `Lawyer.findOne({user: id})`
   * first and falls back to `Lawyer.findById`. Called with the signed-in
   * lawyer's own id to load their profile.
   */
  async getProfile(userId: string): Promise<LawyerProfileDetail> {
    const response = await apiClient.get<ApiSuccess<LawyerProfileDetail>>(
      `/lawyers/${userId}`,
    );
    return unwrap(response);
  },

  /**
   * PUT /lawyers/profile
   *
   * Updates the signed-in lawyer's own record; the controller takes the id
   * from the token, so there is no way to address another lawyer's profile.
   * Only the fields it destructures are honoured — see LawyerProfileUpdate.
   */
  async updateProfile(
    payload: LawyerProfileUpdate,
  ): Promise<LawyerProfileDetail> {
    const response = await apiClient.put<ApiSuccess<LawyerProfileDetail>>(
      '/lawyers/profile',
      payload,
    );
    return unwrap(response);
  },

  /**
   * POST /cases/:id/accept-request
   *
   * Assigns the case to this lawyer, moves it to "Accepted" and opens a chat
   * with the client. 403 if they are neither the selected lawyer nor is the
   * case an unclaimed "Submitted" one.
   */
  async acceptLead(caseId: string): Promise<void> {
    await apiClient.post(`/cases/${caseId}/accept-request`);
  },

  /**
   * POST /cases/:id/reject-request
   *
   * Only the **selected** lawyer may reject; an unclaimed case cannot be
   * rejected, only ignored. The UI hides the reject action accordingly.
   */
  async rejectLead(caseId: string): Promise<void> {
    await apiClient.post(`/cases/${caseId}/reject-request`);
  },

  /** POST /cases/:id/start — moves an accepted case to "In Progress". */
  async startCase(caseId: string): Promise<void> {
    await apiClient.post(`/cases/${caseId}/start`);
  },

  /** POST /cases/:id/complete — moves an in-progress case to "Completed". */
  async markCaseCompleted(caseId: string): Promise<void> {
    await apiClient.post(`/cases/${caseId}/complete`);
  },

  /** GET /cases/hearings/mine — 403 for any role other than lawyer. */
  async getHearings(): Promise<LawyerHearing[]> {
    const response = await apiClient.get<ApiSuccess<LawyerHearing[]>>(
      '/cases/hearings/mine',
    );
    return unwrap(response) ?? [];
  },

  /**
   * POST /cases/:id/hearings
   *
   * `canManageHearings` gates it server-side: 403 unless this lawyer is the
   * case's assigned or selected advocate. The date is required and must parse;
   * everything else defaults, and `court` falls back to the case's
   * `preferredCourt` when omitted.
   *
   * The controller also notifies the client and re-derives the case's
   * `nextHearing`, so the cases list is invalidated alongside the hearings one.
   */
  async addHearing(caseId: string, payload: HearingInput): Promise<void> {
    await apiClient.post(`/cases/${encodeURIComponent(caseId)}/hearings`, payload);
  },

  /**
   * PUT /cases/:id/hearings/:hearingId
   *
   * Partial: only the keys sent are written. Used for editing, rescheduling,
   * cancelling and marking complete — the last three are a `status` change and
   * nothing more, because the backend models them as one field rather than as
   * separate endpoints.
   */
  async updateHearing(
    caseId: string,
    hearingId: string,
    payload: Partial<HearingInput>,
  ): Promise<void> {
    await apiClient.put(
      `/cases/${encodeURIComponent(caseId)}/hearings/${encodeURIComponent(
        hearingId,
      )}`,
      payload,
    );
  },

  /** DELETE /cases/:id/hearings/:hearingId — removes the entry outright. */
  async deleteHearing(caseId: string, hearingId: string): Promise<void> {
    await apiClient.delete(
      `/cases/${encodeURIComponent(caseId)}/hearings/${encodeURIComponent(
        hearingId,
      )}`,
    );
  },

  // ── Notes ───────────────────────────────────────────────────────────────
  //
  // Notes are a subdocument array on `Client`, not a collection, so every one
  // of these is addressed through the client it belongs to. There is no
  // "all my notes" endpoint; the workspace composes one by asking per client.
  //
  // Authorisation is the controller's: `resolveClientForLawyer` refuses a
  // client this advocate has no case with, `getNotes` filters the array to
  // notes this advocate authored, and update and delete check authorship
  // again. None of that is re-implemented here, and none of it can be
  // bypassed from this side.

  /** GET /clients/:id/notes — this lawyer's own notes on that client. */
  async getClientNotes(clientId: string, caseId?: string): Promise<LawyerNote[]> {
    const response = await apiClient.get<ApiSuccess<LawyerNote[]>>(
      `/clients/${encodeURIComponent(clientId)}/notes`,
      caseId ? { params: { caseId } } : undefined,
    );
    return unwrap(response) ?? [];
  },

  /** POST /clients/:id/notes — `text` is required; 400 if blank. */
  async addClientNote(
    clientId: string,
    payload: LawyerNoteInput,
  ): Promise<LawyerNote> {
    const response = await apiClient.post<ApiSuccess<LawyerNote>>(
      `/clients/${encodeURIComponent(clientId)}/notes`,
      payload,
    );
    return unwrap(response);
  },

  /** PUT /clients/:id/notes/:noteId — author-only, 404 otherwise. */
  async updateClientNote(
    clientId: string,
    noteId: string,
    payload: LawyerNoteInput,
  ): Promise<LawyerNote> {
    const response = await apiClient.put<ApiSuccess<LawyerNote>>(
      `/clients/${encodeURIComponent(clientId)}/notes/${encodeURIComponent(
        noteId,
      )}`,
      payload,
    );
    return unwrap(response);
  },

  /** DELETE /clients/:id/notes/:noteId — author-only. */
  async deleteClientNote(clientId: string, noteId: string): Promise<void> {
    await apiClient.delete(
      `/clients/${encodeURIComponent(clientId)}/notes/${encodeURIComponent(
        noteId,
      )}`,
    );
  },

  /** GET /appointments — scoped to this lawyer by the controller. */
  async getAppointments(): Promise<Appointment[]> {
    const response = await apiClient.get<ApiSuccess<Appointment[]>>(
      '/appointments',
    );
    return unwrap(response) ?? [];
  },

  /** POST /appointments — creates a new appointment for a client. */
  async createAppointment(payload: {
    client: string;
    date: string;
    timeSlot: string;
    mode: 'Chat' | 'In-Person';
    caseId?: string;
  }): Promise<Appointment> {
    const response = await apiClient.post<ApiSuccess<Appointment>>(
      '/appointments',
      payload,
    );
    return unwrap(response);
  },

  /** PUT /appointments/:id/status — pending | confirmed | completed | cancelled. */
  async updateAppointmentStatus(
    appointmentId: string,
    status: Appointment['status'],
  ): Promise<Appointment> {
    const response = await apiClient.put<ApiSuccess<Appointment>>(
      `/appointments/${appointmentId}/status`,
      { status },
    );
    return unwrap(response);
  },

  /** DELETE /appointments/:id — the controller cancels rather than destroys. */
  async cancelAppointment(appointmentId: string): Promise<void> {
    await apiClient.delete(`/appointments/${appointmentId}`);
  },

  /**
   * GET /subscriptions
   *
   * Plural. The router is mounted at `/api/subscriptions` in backend/src/app.js
   * even though the file and controller are singular.
   *
   * Always resolves: with no active row the controller synthesises a Free
   * plan rather than returning 404.
   */
  async getSubscription(): Promise<SubscriptionInfo> {
    const response = await apiClient.get<ApiSuccess<SubscriptionInfo>>(
      '/subscriptions',
    );
    return unwrap(response);
  },
};
