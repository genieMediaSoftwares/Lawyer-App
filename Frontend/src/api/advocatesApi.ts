import { apiClient, unwrap } from './apiClient';
import type { ApiSuccess } from '../types/api';
import type {
  FavoriteEntry,
  LawyerProfile,
  RecommendedLawyer,
} from '../types/domain';

/**
 * Advocate discovery, from backend/src/controllers/lawyer/lawyerController.js.
 *
 * The filters below are the ones the controller actually reads off
 * `req.query`. Search, location, verification and availability are applied to
 * the User collection; specialization, experience, fee, rating and language to
 * the Lawyer collection; sorting happens in memory on the server.
 *
 * Every value is passed through verbatim, including the server's own odd
 * spellings — `rating` arrives as "4★+" and `sortBy` as "Highest Rated",
 * because that is what the controller parses. Inventing tidier values here
 * would mean the filter silently does nothing.
 *
 * There is **no pagination** on this endpoint.
 */

/** Exactly the experience buckets the controller branches on. */
export const EXPERIENCE_BUCKETS = ['0-2', '3-5', '5-10', '10+'] as const;
export type ExperienceBucket = (typeof EXPERIENCE_BUCKETS)[number];

/** Exactly the strings the controller's sort branch compares against. */
export const SORT_OPTIONS = [
  'Highest Rated',
  'Most Reviewed',
  'Name (A - Z)',
  'Name (Z - A)',
  'Newest First',
] as const;
export type SortOption = (typeof SORT_OPTIONS)[number];

export interface AdvocateFilters {
  /** Matched against `fullName` as a case-insensitive regex. */
  search?: string;
  specialization?: string;
  location?: string;
  experience?: ExperienceBucket;
  minFee?: number;
  maxFee?: number;
  /** The controller strips "★+" then parses a float, so "4★+" works. */
  rating?: string;
  language?: string | string[];
  verifiedOnly?: boolean;
  availableNow?: boolean;
  sortBy?: SortOption;
}

/**
 * Only defined, non-empty values are sent.
 *
 * The controller treats the literal strings "All", "All Locations",
 * "All Practice Areas", "All Experience" and "All Ratings" as "no filter", but
 * omitting the key entirely is clearer and does the same thing.
 */
const toQuery = (filters: AdvocateFilters): Record<string, string | string[]> => {
  const params: Record<string, string | string[]> = {};

  if (filters.search?.trim()) {
    params.search = filters.search.trim();
  }
  if (filters.specialization) {
    params.specialization = filters.specialization;
  }
  if (filters.location) {
    params.location = filters.location;
  }
  if (filters.experience) {
    params.experience = filters.experience;
  }
  if (typeof filters.minFee === 'number') {
    params.minFee = String(filters.minFee);
  }
  if (typeof filters.maxFee === 'number') {
    params.maxFee = String(filters.maxFee);
  }
  if (filters.rating) {
    params.rating = filters.rating;
  }
  if (filters.language) {
    params.language = filters.language;
  }
  // Compared against the string "true" on the server, so only send it when on.
  if (filters.verifiedOnly) {
    params.verifiedOnly = 'true';
  }
  if (filters.availableNow) {
    params.availableNow = 'true';
  }
  if (filters.sortBy) {
    params.sortBy = filters.sortBy;
  }

  return params;
};

export const advocatesApi = {
  /**
   * GET /lawyers
   *
   * Returns Lawyer profiles with `user` populated. Server-side filtering, so
   * a search term goes to the backend rather than being applied to a cached
   * list.
   */
  async list(filters: AdvocateFilters = {}): Promise<LawyerProfile[]> {
    const response = await apiClient.get<ApiSuccess<LawyerProfile[]>>(
      '/lawyers',
      { params: toQuery(filters) },
    );
    return unwrap(response) ?? [];
  },

  /**
   * GET /lawyers/:id
   *
   * `id` is the **User** id, not the Lawyer document id — the route resolves
   * the profile from the user. Passing a Lawyer `_id` here returns 404.
   */
  async getById(userId: string): Promise<LawyerProfile> {
    const response = await apiClient.get<ApiSuccess<LawyerProfile>>(
      `/lawyers/${encodeURIComponent(userId)}`,
    );
    return unwrap(response);
  },

  /**
   * GET /lawyers/recommend
   *
   * Backed by services/lawyer/lawyerRecommendationService.js, which scores
   * every lawyer on location, speciality, rating, experience and verification
   * and returns the top `limit`, already sorted.
   *
   * `category` is **required** — the controller 400s without it.
   *
   * Recognised `sortBy` values are exactly "Best Match", "Experience",
   * "Rating" and "Fees: Low to High"; anything else falls back to match order.
   *
   * ── Why the return type is not LawyerProfile ──────────────────────────────
   *
   * It was, and that was wrong. This endpoint returns a flat projection with
   * the user's fields hoisted — `fullName` at the top level, no `user` object,
   * and the Lawyer and User ids split into `lawyerId` and `userId`. Reading it
   * as a `LawyerProfile` gave `undefined` for every displayed field. Nothing
   * consumed it yet, so correcting the type here broke no caller.
   */
  async recommend(
    params: Record<string, string> = {},
  ): Promise<RecommendedLawyer[]> {
    const response = await apiClient.get<ApiSuccess<RecommendedLawyer[]>>(
      '/lawyers/recommend',
      { params },
    );
    return unwrap(response) ?? [];
  },
};

/**
 * Favourites, from backend/src/controllers/favorite/favoriteController.js.
 *
 * `POST /favorites` is a **toggle**, not an add: it deletes an existing row or
 * creates a missing one and reports which it did. The screens rely on that —
 * the heart button sends one request either way.
 */
export const favoritesApi = {
  /** GET /favorites → `{_id, lawyer, profile}[]`. */
  async list(): Promise<FavoriteEntry[]> {
    const response = await apiClient.get<ApiSuccess<FavoriteEntry[]>>(
      '/favorites',
    );
    return unwrap(response) ?? [];
  },

  /**
   * POST /favorites  body `{lawyerId}` — the lawyer's **User** id.
   *
   * @returns the state the row is now in, as the server reports it.
   */
  async toggle(lawyerUserId: string): Promise<{ isFavorite: boolean }> {
    const response = await apiClient.post<
      ApiSuccess<{ isFavorite: boolean }>
    >('/favorites', { lawyerId: lawyerUserId });
    return unwrap(response);
  },

  /** DELETE /favorites/:id — `id` is the Favorite row's own `_id`. */
  async remove(favoriteId: string): Promise<void> {
    await apiClient.delete<ApiSuccess<null>>(
      `/favorites/${encodeURIComponent(favoriteId)}`,
    );
  },
};
