import { lazy, Suspense } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import { useAuth } from './AuthContext';
import AdminLayout from '@/layouts/AdminLayout';
import Spinner from '@/components/Spinner';

// Pages — lazy loaded so initial bundle stays small
const LoginPage            = lazy(() => import('@/pages/auth/LoginPage'));
const DashboardPage        = lazy(() => import('@/pages/dashboard/DashboardPage'));
const UsersPage            = lazy(() => import('@/pages/users/UsersPage'));
const UserDetailPage       = lazy(() => import('@/pages/users/UserDetailPage'));
const VerificationPage     = lazy(() => import('@/pages/verification/VerificationPage'));
const VerificationDetail   = lazy(() => import('@/pages/verification/VerificationDetailPage'));
const ReferencesPage       = lazy(() => import('@/pages/references/ReferencesPage'));
const ReportsPage          = lazy(() => import('@/pages/reports/ReportsPage'));
const ReportDetailPage     = lazy(() => import('@/pages/reports/ReportDetailPage'));
const AdminsPage           = lazy(() => import('@/pages/admins/AdminsPage'));
const CreateAdminPage      = lazy(() => import('@/pages/admins/CreateAdminPage'));
const AuditLogsPage        = lazy(() => import('@/pages/audit/AuditLogsPage'));
const SettingsPage         = lazy(() => import('@/pages/settings/SettingsPage'));

function LoadingFallback() {
  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh' }}>
      <Spinner size={32} />
    </div>
  );
}

function RequireAuth({ children }: { children: React.ReactNode }) {
  const { admin, isLoading } = useAuth();
  if (isLoading) return <LoadingFallback />;
  if (!admin) return <Navigate to="/login" replace />;
  return <>{children}</>;
}

function RequireSuperAdmin({ children }: { children: React.ReactNode }) {
  const { admin } = useAuth();
  if (admin && admin.role !== 'super_admin') {
    return (
      <div className="alert alert-error" style={{ margin: 24 }}>
        ⚠ You don't have permission to access this page.
      </div>
    );
  }
  return <>{children}</>;
}

export default function AppRouter() {
  return (
    <Suspense fallback={<LoadingFallback />}>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/" element={<Navigate to="/admin/dashboard" replace />} />

        <Route
          path="/admin"
          element={
            <RequireAuth>
              <AdminLayout />
            </RequireAuth>
          }
        >
          <Route index element={<Navigate to="dashboard" replace />} />
          <Route path="dashboard"    element={<DashboardPage />} />
          <Route path="users"        element={<UsersPage />} />
          <Route path="users/:id"    element={<UserDetailPage />} />
          <Route path="verification" element={<VerificationPage />} />
          <Route path="verification/:id" element={<VerificationDetail />} />
          <Route path="references"   element={<ReferencesPage />} />
          <Route path="reports"      element={<ReportsPage />} />
          <Route path="reports/:id"  element={<ReportDetailPage />} />
          <Route path="settings"     element={<SettingsPage />} />

          {/* Super admin only */}
          <Route path="admins" element={<RequireSuperAdmin><AdminsPage /></RequireSuperAdmin>} />
          <Route path="admins/new" element={<RequireSuperAdmin><CreateAdminPage /></RequireSuperAdmin>} />
          <Route path="audit-logs" element={<RequireSuperAdmin><AuditLogsPage /></RequireSuperAdmin>} />
        </Route>

        {/* Catch-all */}
        <Route path="*" element={<Navigate to="/admin/dashboard" replace />} />
      </Routes>
    </Suspense>
  );
}
