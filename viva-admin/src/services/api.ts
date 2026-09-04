import axios, { AxiosError, type AxiosInstance } from 'axios';

const BASE_URL = import.meta.env.VITE_API_BASE_URL as string;

// ─── Token storage ────────────────────────────────────────────────────────────
// sessionStorage: cleared when tab closes. Safer than localStorage for JWTs.
const TOKEN_KEY = 'viva_admin_token';

export const tokenStore = {
  get: (): string | null => sessionStorage.getItem(TOKEN_KEY),
  set: (t: string): void => { sessionStorage.setItem(TOKEN_KEY, t); },
  clear: (): void => { sessionStorage.removeItem(TOKEN_KEY); },
};

// ─── Axios instance ───────────────────────────────────────────────────────────

const http: AxiosInstance = axios.create({
  baseURL: BASE_URL,
  timeout: 30_000,
  headers: { 'Content-Type': 'application/json' },
});

http.interceptors.request.use((config) => {
  const token = tokenStore.get();
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

// 401 → clear token; the AuthContext listener handles the redirect.
let _on401: (() => void) | null = null;
export function setOn401Handler(fn: () => void): void {
  _on401 = fn;
}

http.interceptors.response.use(
  (r) => r,
  (err: AxiosError) => {
    if (err.response?.status === 401) {
      tokenStore.clear();
      _on401?.();
    }
    return Promise.reject(err);
  },
);

// ─── Error helper ────────────────────────────────────────────────────────────

export function apiErrorMessage(err: unknown): string {
  if (axios.isAxiosError(err)) {
    const status = err.response?.status;
    const detail = (err.response?.data as { detail?: string })?.detail;
    if (detail && typeof detail === 'string') return detail;
    switch (status) {
      case 400: return 'Invalid request. Please check your input.';
      case 401: return 'Session expired. Please log in again.';
      case 403: return "You don't have permission to perform this action.";
      case 404: return 'The requested record could not be found.';
      case 409: return 'This action has already been completed.';
      case 422: return 'Invalid data submitted.';
      case 429: return 'Too many requests. Please try again shortly.';
      case 500:
      case 502:
      case 503: return 'Something went wrong on the server. Please try again.';
      default:
        if (!err.response) return 'Network error. Check your connection.';
    }
  }
  return 'An unexpected error occurred.';
}

// ─── API methods ──────────────────────────────────────────────────────────────

export const api = {
  // Auth
  login: (email: string, password: string) =>
    http.post('/admin/login', { email, password }),

  // Dashboard
  getDashboard: () => http.get('/admin/dashboard'),

  // Users
  getUsers: (params: Record<string, string | number | undefined>) =>
    http.get('/admin/users', { params }),
  getUser: (id: string) => http.get(`/admin/users/${id}`),
  suspendUser: (id: string, reason: string) =>
    http.post(`/admin/users/${id}/suspend`, { reason, confirm: true }),
  banUser: (id: string, reason: string) =>
    http.post(`/admin/users/${id}/ban`, { reason, confirm: true }),
  restoreUser: (id: string) => http.post(`/admin/users/${id}/restore`),

  // Certificates
  getCertificates: (status_filter: string, page = 1, page_size = 20) =>
    http.get('/admin/certificates', { params: { status_filter, page, page_size } }),
  viewCertificate: (docId: string) =>
    http.get(`/admin/certificates/${docId}/view`),
  approveCertificate: (docId: string) =>
    http.post(`/admin/certificates/${docId}/approve`),
  rejectCertificate: (docId: string, rejection_reason: string) =>
    http.post(`/admin/certificates/${docId}/reject`, { rejection_reason }),

  // References
  getReferences: (status?: string, page = 1, page_size = 20) =>
    http.get('/admin/references', { params: { status, page, page_size } }),

  // Reports
  getReports: (report_status = 'open', page = 1, page_size = 20) =>
    http.get('/admin/reports', { params: { report_status, page, page_size } }),
  resolveReport: (id: string, resolution_note: string) =>
    http.post(`/admin/reports/${id}/resolve`, { resolution_note }),
  dismissReport: (id: string, resolution_note: string) =>
    http.post(`/admin/reports/${id}/dismiss`, { resolution_note }),

  // Admin management (super_admin only)
  getAdmins: (page = 1, page_size = 20) =>
    http.get('/admin/admins', { params: { page, page_size } }),
  createAdmin: (data: { full_name: string; email: string; role: string; password: string }) =>
    http.post('/admin/admins', data),
  updateAdminStatus: (id: string, is_active: boolean) =>
    http.patch(`/admin/admins/${id}`, { is_active }),

  // Audit logs (super_admin only)
  getAuditLogs: (params?: Record<string, string | number | undefined>) =>
    http.get('/admin/audit-logs', { params }),

  // Settings (super_admin only)
  getSettings: () => http.get('/admin/settings'),
  updateSettings: (data: Record<string, unknown>) =>
    http.put('/admin/settings', data),
};
