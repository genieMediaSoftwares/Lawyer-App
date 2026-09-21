import { apiClient, unwrap } from './apiClient';
import type { ApiSuccess } from '../types/api';
import type { CaseHearing, CreateCasePayload, LegalCase } from '../types/domain';

/**
 * Case endpoints, from backend/src/routes/case.routes.js.
 *
 * ── Contract notes that shape the UI ──────────────────────────────────────
 *
 * `GET /cases` takes **no query parameters and returns no pagination
 * envelope**. The controller builds `{client: req.user._id}` for a client,
 * sorts by `createdAt` descending and returns the whole array. So:
 *
 *   - Filtering by tab (All / In Progress / Closed) happens on the client,
 *     over data already in hand. That is not "fetching everything and
 *     filtering locally" in the sense §14 warns about — there is no
 *     server-side alternative to prefer.
 *   - There is nothing to paginate against. The list is rendered with FlatList
 *     and windowing so a large array stays smooth, and `getInProgress` /
 *     `getClosed` below are used where they genuinely narrow the query
 *     server-side.
 *
 * Reported as a gap rather than worked around: see README, "Missing backend
 * support".
 */

export const casesApi = {
  /**
   * POST /cases
   *
   * Files a new case for the signed-in client. The client id comes from the
   * token — `req.user._id` — so there is no way to file on someone else's
   * behalf and nothing here sends one.
   *
   * Two outcomes, decided server-side by whether `selectedLawyer` is present:
   *
   *   - with it, the case is created as **"Awaiting Lawyer Acceptance"** and
   *     only that lawyer is notified;
   *   - without it, as **"Submitted"**, and every lawyer is notified.
   *
   * Returns the created Case document (201).
   */
  async create(payload: CreateCasePayload): Promise<LegalCase> {
    const response = await apiClient.post<ApiSuccess<LegalCase>>(
      '/cases',
      payload,
    );
    return unwrap(response);
  },

  /**
   * GET /cases
   *
   * Every case belonging to the signed-in client, newest first, with `client`,
   * `assignedLawyer`, `selectedLawyer` and `proposals.lawyer` populated. The
   * controller additionally attaches `selectedLawyerProfile` and
   * `assignedLawyerProfile` by looking up the Lawyer document for each.
   */
  async list(): Promise<LegalCase[]> {
    const response = await apiClient.get<ApiSuccess<LegalCase[]>>('/cases');
    return unwrap(response) ?? [];
  },

  /**
   * GET /cases/status/in-progress
   *
   * A genuinely narrower server-side query, kept separate from `list()` so the
   * tab that wants only active cases does not pull the closed ones too.
   */
  async listInProgress(): Promise<LegalCase[]> {
    const response = await apiClient.get<ApiSuccess<LegalCase[]>>(
      '/cases/status/in-progress',
    );
    return unwrap(response) ?? [];
  },

  /** GET /cases/status/closed */
  async listClosed(): Promise<LegalCase[]> {
    const response = await apiClient.get<ApiSuccess<LegalCase[]>>(
      '/cases/status/closed',
    );
    return unwrap(response) ?? [];
  },

  /** GET /cases/:id */
  async getById(id: string): Promise<LegalCase> {
    const response = await apiClient.get<ApiSuccess<LegalCase>>(
      `/cases/${encodeURIComponent(id)}`,
    );
    return unwrap(response);
  },

  /**
   * GET /cases/:id/timeline
   *
   * The response shape is the controller's own composition rather than a
   * model, so it is read defensively: the Case Details screen renders whatever
   * entries come back and shows an empty state when there are none.
   */
  async getTimeline(id: string): Promise<unknown> {
    const response = await apiClient.get<ApiSuccess<unknown>>(
      `/cases/${encodeURIComponent(id)}/timeline`,
    );
    return unwrap(response);
  },

  /** GET /cases/hearings/mine — hearings across all of the user's cases. */
  async getMyHearings(): Promise<CaseHearing[]> {
    const response = await apiClient.get<ApiSuccess<CaseHearing[]>>(
      '/cases/hearings/mine',
    );
    return unwrap(response) ?? [];
  },
};
