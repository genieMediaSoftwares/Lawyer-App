import { apiClient, unwrap } from './apiClient';
import type { ApiSuccess } from '../types/api';
import type { CaseHearing, CreateCasePayload, LegalCase } from '../types/domain';

export const casesApi = {
  async create(payload: CreateCasePayload): Promise<LegalCase> {
    const response = await apiClient.post<ApiSuccess<LegalCase>>(
      '/cases',
      payload,
    );
    return unwrap(response);
  },

  async list(): Promise<LegalCase[]> {
    const response = await apiClient.get<ApiSuccess<LegalCase[]>>('/cases');
    return unwrap(response) ?? [];
  },

  async listInProgress(): Promise<LegalCase[]> {
    const response = await apiClient.get<ApiSuccess<LegalCase[]>>(
      '/cases/status/in-progress',
    );
    return unwrap(response) ?? [];
  },

  async listClosed(): Promise<LegalCase[]> {
    const response = await apiClient.get<ApiSuccess<LegalCase[]>>(
      '/cases/status/closed',
    );
    return unwrap(response) ?? [];
  },

  async getById(id: string): Promise<LegalCase> {
    const response = await apiClient.get<ApiSuccess<LegalCase>>(
      `/cases/${encodeURIComponent(id)}`,
    );
    return unwrap(response);
  },

  async getTimeline(id: string): Promise<unknown> {
    const response = await apiClient.get<ApiSuccess<unknown>>(
      `/cases/${encodeURIComponent(id)}/timeline`,
    );
    return unwrap(response);
  },

  async getMyHearings(): Promise<CaseHearing[]> {
    const response = await apiClient.get<ApiSuccess<CaseHearing[]>>(
      '/cases/hearings/mine',
    );
    return unwrap(response) ?? [];
  },
};
