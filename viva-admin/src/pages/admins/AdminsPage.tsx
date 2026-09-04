import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '@/services/api';
import { useTitle } from '@/hooks/useTitle';
import type { AdminSummary, AdminsResponse } from '@/types';
import { apiErrorMessage } from '@/app/AuthContext';
import StatusBadge from '@/components/StatusBadge';
import ConfirmDialog from '@/components/ConfirmDialog';
import TableSkeleton from '@/components/TableSkeleton';
import ErrorAlert from '@/components/ErrorAlert';
import EmptyState from '@/components/EmptyState';
import { cap, fmtDate, timeAgo } from '@/utils/format';

export default function AdminsPage() {
  useTitle('Admin Users');
  const [admins, setAdmins]   = useState<AdminSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError]     = useState<string | null>(null);
  const [toggling, setToggling] = useState<string | null>(null);
  const [confirmAdmin, setConfirmAdmin] = useState<AdminSummary | null>(null);
  const [actionErr, setActionErr] = useState<string | null>(null);

  function load() {
    setLoading(true);
    setError(null);
    api.getAdmins()
      .then(r => setAdmins((r.data as AdminsResponse).admins ?? []))
      .catch(err => setError(apiErrorMessage(err)))
      .finally(() => setLoading(false));
  }

  useEffect(load, []);

  async function toggleAdmin(admin: AdminSummary) {
    setToggling(admin.id);
    setActionErr(null);
    try {
      await api.updateAdminStatus(admin.id, !admin.is_active);
      setConfirmAdmin(null);
      load();
    } catch (err) {
      setActionErr(apiErrorMessage(err));
    } finally {
      setToggling(null);
    }
  }

  return (
    <>
      <div className="page-header">
        <div>
          <h1 className="page-title">Admin Users</h1>
          <p className="page-subtitle">Manage administrator accounts</p>
        </div>
        <Link to="/admin/admins/new" className="btn btn-primary">+ Create Admin</Link>
      </div>

      <ErrorAlert message={error} onRetry={load} />
      <ErrorAlert message={actionErr} />

      <div className="card">
        <div className="table-wrap">
          {loading ? (
            <TableSkeleton rows={5} cols={6} />
          ) : admins.length === 0 ? (
            <EmptyState icon="🛡" title="No admin accounts" />
          ) : (
            <table className="data-table">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Email</th>
                  <th>Role</th>
                  <th>Status</th>
                  <th>Last Login</th>
                  <th>Created</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {admins.map(a => (
                  <tr key={a.id}>
                    <td style={{ fontWeight: 500 }}>{a.full_name}</td>
                    <td style={{ fontSize: 12, color: 'var(--c-text-secondary)' }}>{a.email}</td>
                    <td>
                      <span className={`badge ${a.role === 'super_admin' ? 'badge-verified' : 'badge-active'}`}>
                        {cap(a.role)}
                      </span>
                    </td>
                    <td>
                      <span className={`badge ${a.is_active ? 'badge-active' : 'badge-suspended'}`}>
                        {a.is_active ? '✓ Active' : '⚠ Disabled'}
                      </span>
                    </td>
                    <td style={{ fontSize: 12, color: 'var(--c-text-tertiary)' }}>
                      {timeAgo(a.last_login_at)}
                    </td>
                    <td style={{ fontSize: 12, color: 'var(--c-text-tertiary)' }}>{fmtDate(a.created_at)}</td>
                    <td>
                      <button
                        className={`btn btn-sm ${a.is_active ? 'btn-danger' : 'btn-success'}`}
                        onClick={() => setConfirmAdmin(a)}
                        disabled={toggling === a.id}
                      >
                        {toggling === a.id
                          ? '…'
                          : a.is_active ? 'Disable' : 'Enable'}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>

      {confirmAdmin && (
        <ConfirmDialog
          title={confirmAdmin.is_active ? 'Disable Admin?' : 'Enable Admin?'}
          message={
            confirmAdmin.is_active
              ? `${confirmAdmin.full_name} will lose access to the admin panel.`
              : `${confirmAdmin.full_name} will regain access to the admin panel.`
          }
          confirmLabel={confirmAdmin.is_active ? 'Disable' : 'Enable'}
          variant={confirmAdmin.is_active ? 'danger' : 'warning'}
          isLoading={!!toggling}
          onConfirm={() => toggleAdmin(confirmAdmin)}
          onCancel={() => setConfirmAdmin(null)}
        />
      )}
    </>
  );
}
