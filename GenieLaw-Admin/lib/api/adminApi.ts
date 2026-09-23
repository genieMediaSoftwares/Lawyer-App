import { api } from "./axios";

export const adminApi = {
  // Stats & Analytics
  getDashboardStats: () => api.get("/admin/stats").then((res) => res.data.data),
  getAnalyticsData: () => api.get("/admin/analytics").then((res) => res.data.data),
  getAiAnalytics: () => api.get("/admin/ai-analytics").then((res) => res.data.data),
  getReports: (reportType = "cases") => api.get(`/admin/reports?reportType=${reportType}`).then((res) => res.data),

  // Clients
  getClients: (params?: { page?: number; limit?: number; search?: string; status?: string }) =>
    api.get("/admin/clients", { params }).then((res) => res.data),
  getClientById: (id: string) => api.get(`/admin/clients/${id}`).then((res) => res.data.data),
  updateClientStatus: (id: string, isActive: boolean) =>
    api.put(`/admin/clients/${id}/status`, { isActive }).then((res) => res.data),

  // Lawyers & Verification
  getLawyers: (params?: { page?: number; limit?: number; search?: string; verificationStatus?: string }) =>
    api.get("/admin/lawyers", { params }).then((res) => res.data),
  getLawyerById: (id: string) => api.get(`/admin/lawyers/${id}`).then((res) => res.data.data),
  verifyLawyer: (id: string, data: { status: string; rejectionReason?: string; isActive?: boolean }) =>
    api.put(`/admin/lawyers/${id}/verify`, data).then((res) => res.data),
  updateLawyerStatus: (id: string, data: { isActive?: boolean; verificationStatus?: string }) =>
    api.put(`/admin/lawyers/${id}/status`, data).then((res) => res.data),
  updateLawyerVerification: (id: string, data: { verificationStatus: string; notes?: string }) =>
    api.put(`/admin/lawyers/${id}/verify`, { status: data.verificationStatus, rejectionReason: data.notes }).then((res) => res.data),

  // Cases
  getCases: (params?: { page?: number; limit?: number; search?: string; status?: string }) =>
    api.get("/admin/cases", { params }).then((res) => res.data),
  getUrgentCases: () => api.get("/admin/cases/urgent").then((res) => res.data),
  getCaseById: (id: string) => api.get(`/admin/cases/${id}`).then((res) => res.data.data),
  updateCaseStatus: (id: string, data: { status?: string; priority?: string }) =>
    api.put(`/admin/cases/${id}/status`, data).then((res) => res.data),

  // Appointments & Consultations
  getAppointments: (params?: { page?: number; limit?: number; search?: string; status?: string }) =>
    api.get("/admin/appointments", { params }).then((res) => res.data),

  // Documents
  getDocuments: (params?: { page?: number; limit?: number; search?: string; category?: string }) =>
    api.get("/admin/documents", { params }).then((res) => res.data.data || res.data),

  // Payments & Refunds
  getPayments: (params?: { page?: number; limit?: number; search?: string; status?: string }) =>
    api.get("/admin/payments", { params }).then((res) => res.data),
  processRefund: (paymentId: string, reason: string) =>
    api.post(`/admin/payments/${paymentId}/refund`, { reason }).then((res) => res.data),

  // Subscriptions
  getSubscriptions: (params?: { page?: number; limit?: number; search?: string; status?: string }) =>
    api.get("/admin/subscriptions", { params }).then((res) => res.data),
  updateSubscription: (id: string, data: { plan?: string; status?: string; endDate?: string }) =>
    api.put(`/admin/subscriptions/${id}`, data).then((res) => res.data),

  // Reviews & Moderation
  getReviews: (params?: { page?: number; limit?: number; search?: string; status?: string; isReported?: string }) =>
    api.get("/admin/reviews", { params }).then((res) => res.data),
  updateReviewVisibility: (id: string, data: { isHidden?: boolean; isReported?: boolean }) =>
    api.put(`/admin/reviews/${id}/visibility`, data).then((res) => res.data),
  moderateReview: (id: string, action: string) =>
    api.put(`/admin/reviews/${id}/moderate`, { action }).then((res) => res.data),

  // Support Tickets & Disputes
  getSupportTickets: (params?: { search?: string; status?: string }) =>
    api.get("/admin/support-tickets", { params }).then((res) => res.data),
  updateSupportTicket: (id: string, status: string) =>
    api.put(`/admin/support-tickets/${id}`, { status }).then((res) => res.data),
  getDisputes: (params?: { page?: number; limit?: number; search?: string; status?: string }) =>
    api.get("/admin/disputes", { params }).then((res) => res.data.data || res.data),

  // Categories & Promotions
  getCategories: () => api.get("/admin/categories").then((res) => res.data.data),
  createCategory: (data: { name: string; description?: string }) =>
    api.post("/admin/categories", data).then((res) => res.data),
  updateCategory: (id: string, data: { name?: string; description?: string; isActive?: boolean }) =>
    api.put(`/admin/categories/${id}`, data).then((res) => res.data),
  deleteCategory: (id: string) => api.delete(`/admin/categories/${id}`).then((res) => res.data),
  getPromotions: () => api.get("/admin/promotions").then((res) => res.data.data || res.data),
  createPromotion: (data: { code: string; discount: number; validUntil: string; usageLimit: number }) =>
    api.post("/admin/promotions", data).then((res) => res.data),
  togglePromotion: (id: string, active: boolean) =>
    api.put(`/admin/promotions/${id}`, { active }).then((res) => res.data),

  // Notifications & Broadcast
  getNotifications: (params?: { page?: number; limit?: number }) =>
    api.get("/admin/notifications", { params }).then((res) => res.data?.data || res.data || []),
  broadcastNotification: (data: { title: string; message: string; targetRole?: string }) =>
    api.post("/admin/notifications/broadcast", data).then((res) => res.data),

  // Legal Documents
  getLegalDocuments: () => api.get("/admin/legal").then((res) => res.data.data || res.data),
  getLegalDocument: (id: string) => api.get(`/admin/legal/${id}`).then((res) => res.data.data),
  createLegalDocument: (data: any) => api.post("/admin/legal", data).then((res) => res.data),
  updateLegalDocument: (id: string, data: any) => api.put(`/admin/legal/${id}`, data).then((res) => res.data),

  // Audit Logs
  getAuditLogs: (params?: { page?: number; limit?: number; action?: string; search?: string }) =>
    api.get("/admin/audit-logs", { params }).then((res) => res.data),

  // Settings
  getSettings: () => api.get("/admin/settings").then((res) => res.data.data),
  updateSettings: (data: any) => api.put("/admin/settings", data).then((res) => res.data),
};
