import { apiClient, unwrap } from './apiClient';
import type { ApiSuccess } from '../types/api';
import type {
  ClientProfileResponse,
  ClientStats,
  NotificationPage,
} from '../types/domain';

/**
 * Client profile and dashboard data.
 *
 * Mounted twice on the server — `/api/client` and `/api/clients` both resolve
 * to backend/src/routes/client.routes.js. The singular form is used here.
 */
export const clientApi = {
  /**
   * GET /client/profile → `{user, profile}`
   *
   * `user` is the raw User document minus the password, so the identifier is
   * `_id`. `profile` is the Client side-document, which the controller creates
   * on first read if the account has none.
   */
  async getProfile(): Promise<ClientProfileResponse> {
    const response = await apiClient.get<ApiSuccess<ClientProfileResponse>>(
      '/client/profile',
    );
    return unwrap(response);
  },

  /**
   * GET /client/stats → `{activeCases, totalCases, totalAppointments,
   * totalDocuments}`
   *
   * Four counts the server computes with `countDocuments`. These are the only
   * figures the dashboard shows; anything the backend does not count is not
   * displayed rather than estimated.
   *
   * Note `activeCases` counts status "In Progress" exactly — not the broader
   * set of open statuses — because that is what the controller queries.
   */
  async getStats(): Promise<ClientStats> {
    const response = await apiClient.get<ApiSuccess<ClientStats>>(
      '/client/stats',
    );
    return unwrap(response);
  },

  /** GET /client/activity — recent activity, shape composed by the controller. */
  async getActivity(): Promise<unknown> {
    const response = await apiClient.get<ApiSuccess<unknown>>(
      '/client/activity',
    );
    return unwrap(response);
  },

  /**
   * PUT /client/profile
   * Updates client profile fields (fullName, mobile, location, dob, gender, languages, etc.)
   */
  async updateProfile(payload: {
    fullName?: string;
    mobile?: string;
    location?: string;
    dob?: string;
    gender?: string;
    languages?: string[];
  }): Promise<ClientProfileResponse> {
    const response = await apiClient.put<ApiSuccess<ClientProfileResponse>>(
      '/client/profile',
      payload,
    );
    return unwrap(response);
  },
};

/**
 * Notifications, from
 * backend/src/controllers/notification/notificationController.js.
 *
 * The one list endpoint in this app with real server-side pagination, so the
 * notifications screen pages properly rather than pretending to.
 */
export const notificationsApi = {
  /**
   * GET /notifications?page=&limit=
   *
   * Defaults on the server are page 1, limit 15.
   *
   * @returns `{notifications, pagination: {total, page, limit, pages},
   *   unreadCount}`
   */
  async list(page = 1, limit = 15): Promise<NotificationPage> {
    const response = await apiClient.get<ApiSuccess<NotificationPage>>(
      '/notifications',
      { params: { page: String(page), limit: String(limit) } },
    );
    return unwrap(response);
  },

  /** PUT /notifications/:id/read */
  async markRead(id: string): Promise<void> {
    await apiClient.put<ApiSuccess<unknown>>(
      `/notifications/${encodeURIComponent(id)}/read`,
    );
  },

  /** PUT /notifications/read-all */
  async markAllRead(): Promise<void> {
    await apiClient.put<ApiSuccess<unknown>>('/notifications/read-all');
  },

  /** DELETE /notifications/:id */
  async remove(id: string): Promise<void> {
    await apiClient.delete<ApiSuccess<unknown>>(
      `/notifications/${encodeURIComponent(id)}`,
    );
  },

  /** DELETE /notifications/clear-all */
  async clearAll(): Promise<void> {
    await apiClient.delete<ApiSuccess<unknown>>('/notifications/clear-all');
  },
};
