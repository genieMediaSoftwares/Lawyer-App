import { apiClient, unwrap } from './apiClient';
import type { ApiSuccess } from '../types/api';
import type { PaymentRecord } from '../types/domain';

export const paymentsApi = {
  async list(): Promise<PaymentRecord[]> {
    const response = await apiClient.get<ApiSuccess<PaymentRecord[]>>('/payments');
    return unwrap(response) ?? [];
  },
};
