// ─── Auth ────────────────────────────────────────────────────────────────────

export type AdminRole = 'super_admin' | 'admin' | 'moderator' | 'support';

export interface AdminUser {
  admin_id: string;
  email: string;
  full_name: string;
  role: AdminRole;
}

export interface LoginResponse {
  access_token: string;
  token_type: string;
  role: AdminRole;
  full_name: string;
}

// ─── Dashboard ───────────────────────────────────────────────────────────────

export interface DashboardStats {
  total_users: number;
  new_users_week: number;
  active_today: number;
  pending_verification: number;
  pending_certificates: number;
  open_reports: number;
  interests_week: number;
  verified_users: number;
}

// ─── Users ───────────────────────────────────────────────────────────────────

export type AccountStatus =
  | 'active'
  | 'pending_verification'
  | 'suspended'
  | 'banned'
  | 'deleted';

export type VerificationStatus = 'unverified' | 'pending' | 'verified' | 'rejected';

export interface UserSummary {
  user_id: string;
  phone: string;
  full_name: string | null;
  account_status: AccountStatus;
  verification_status: VerificationStatus;
  completion_percentage: number | null;
  created_at: string;
  last_active_at: string | null;
}

export interface UserDetail {
  id: string;
  phone_normalized: string;
  account_status: AccountStatus;
  verification_status: VerificationStatus;
  onboarding_completed: boolean;
  created_at: string;
  last_active_at: string | null;
  suspended_at: string | null;
  suspended_reason: string | null;
  banned_at: string | null;
  banned_reason: string | null;
  // profile join
  full_name: string | null;
  gender: string | null;
  date_of_birth: string | null;
  completion_percentage: number | null;
  // verification join
  verification_method: string | null;
  verification_request_status: string | null;
  cert_status: string | null;
}

export interface UsersResponse {
  users: UserSummary[];
  total: number;
  page: number;
  page_size: number;
}

// ─── Verification / Certificates ─────────────────────────────────────────────

export type CertStatus = 'pending' | 'approved' | 'rejected';

export interface CertificateSummary {
  document_id: string;
  user_id: string;
  full_name: string;
  status: CertStatus;
  file_name: string;
  created_at: string;
}

export interface CertificatesResponse {
  certificates: CertificateSummary[];
}

export interface SignedUrlResponse {
  signed_url: string;
  expires_in_seconds: number;
}

// ─── References ──────────────────────────────────────────────────────────────

export type ReferenceStatus = 'pending' | 'confirmed' | 'rejected' | 'revoked';

export interface ReferenceSummary {
  id: string;
  user_id: string;
  reference_user_id: string;
  status: ReferenceStatus;
  created_at: string;
  confirmed_at: string | null;
  rejected_at: string | null;
  // joined
  user_name: string | null;
  reference_name: string | null;
}

export interface ReferencesResponse {
  references: ReferenceSummary[];
}

// ─── Reports ─────────────────────────────────────────────────────────────────

export type ReportStatus = 'open' | 'under_review' | 'resolved' | 'dismissed';

export interface ReportSummary {
  id: string;
  reporter_id: string;
  reported_id: string;
  reason: string;
  description: string | null;
  status: ReportStatus;
  created_at: string;
  reporter_name: string | null;
  reported_name: string | null;
}

export interface ReportsResponse {
  reports: ReportSummary[];
}

// ─── Admin Management ────────────────────────────────────────────────────────

export interface AdminSummary {
  id: string;
  email: string;
  full_name: string;
  role: AdminRole;
  is_active: boolean;
  created_at: string;
  last_login_at: string | null;
}

export interface AdminsResponse {
  admins: AdminSummary[];
  total: number;
}

// ─── Audit Logs ──────────────────────────────────────────────────────────────

export interface AuditLog {
  id: string;
  actor_type: string;
  actor_id: string;
  action: string;
  target_type: string | null;
  target_id: string | null;
  details: Record<string, unknown> | null;
  ip_address: string | null;
  created_at: string;
}

export interface AuditLogsResponse {
  logs: AuditLog[];
}

// ─── Shared ──────────────────────────────────────────────────────────────────

export interface ApiError {
  detail: string;
}

export interface Paginated {
  page: number;
  page_size: number;
  total: number;
}
