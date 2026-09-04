import { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { api } from '@/services/api';
import { useTitle } from '@/hooks/useTitle';
import { useAuth } from '@/app/AuthContext';
import type { UserDetail } from '@/types';
import { apiErrorMessage } from '@/app/AuthContext';
import StatusBadge from '@/components/StatusBadge';
import ConfirmDialog from '@/components/ConfirmDialog';
import ErrorAlert from '@/components/ErrorAlert';
import { cap, fmtDate, fmtDateTime, maskPhone } from '@/utils/format';

type DialogType = 'suspend' | 'ban' | 'restore' | null;

export default function UserDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { can } = useAuth();
  const [user, setUser]       = useState<UserDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError]     = useState<string | null>(null);
  const [dialog, setDialog]   = useState<DialogType>(null);
  const [acting, setActing]   = useState(false);
  const [actionErr, setActionErr] = useState<string | null>(null);
  const [actionOk, setActionOk]   = useState<string | null>(null);

  useTitle(user?.full_name ?? 'User Detail');

  function load() {
    if (!id) return;
    setLoading(true);
    setError(null);
    api.getUser(id)
      .then(r => setUser(r.data as UserDetail))
      .catch(err => setError(apiErrorMessage(err)))
      .finally(() => setLoading(false));
  }

  useEffect(load, [id]);

  async function handleAction(reason?: string) {
    if (!id || !dialog) return;
    setActing(true);
    setActionErr(null);
    setActionOk(null);
    try {
      if (dialog === 'suspend') await api.suspendUser(id, reason ?? '');
      if (dialog === 'ban')     await api.banUser(id, reason ?? '');
      if (dialog === 'restore') await api.restoreUser(id);
      setActionOk(`User ${dialog}ed successfully.`);
      setDialog(null);
      load();
    } catch (err) {
      setActionErr(apiErrorMessage(err));
    } finally {
      setActing(false);
    }
  }

  if (loading) return (
    <div style={{ padding: 32 }}>
      {[1,2,3,4].map(i => (
        <div key={i} className="skeleton" style={{ height: 18, marginBottom: 14, width: `${40 + i * 12}%` }} />
      ))}
    </div>
  );

  if (error) return (
    <div style={{ padding: 16 }}>
      <Link to="/admin/users" className="btn btn-ghost btn-sm" style={{ marginBottom: 16 }}>‹ Back</Link>
      <ErrorAlert message={error} onRetry={load} />
    </div>
  );

  if (!user) return null;

  const canSuspend = can('suspend');
  const canBan     = can('ban');
  const isActive   = user.account_status === 'active' || user.account_status === 'pending_verification';

  return (
    <>
      <div className="page-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <Link to="/admin/users" className="btn btn-ghost btn-sm">‹ Users</Link>
          <h1 className="page-title">{user.full_name ?? 'No name'}</h1>
          <StatusBadge status={user.account_status} />
          <StatusBadge status={user.verification_status} />
        </div>
      </div>

      {actionOk && <div className="alert alert-success" style={{ marginBottom: 16 }}>✓ {actionOk}</div>}
      <ErrorAlert message={actionErr} />

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 300px', gap: 16, alignItems: 'start' }}>
        {/* Left: profile info */}
        <div>
          <div className="card section-card">
            <div className="section-head">👤 Profile</div>
            <div className="section-body">
              <div className="detail-grid">
                <Field label="Full Name"   value={user.full_name} />
                <Field label="Gender"      value={cap(user.gender)} />
                <Field label="Date of Birth" value={fmtDate(user.date_of_birth)} />
                <Field label="Phone"       value={maskPhone(user.phone_normalized)} />
                <Field label="Profile %"   value={`${user.completion_percentage ?? 0}%`} />
                <Field label="Joined"      value={fmtDate(user.created_at)} />
                <Field label="Last Active" value={fmtDateTime(user.last_active_at)} />
                <Field label="Onboarding"  value={user.onboarding_completed ? 'Completed' : 'Incomplete'} />
              </div>
            </div>
          </div>

          <div className="card section-card">
            <div className="section-head">✓ Verification</div>
            <div className="section-body">
              <div className="detail-grid">
                <Field label="Status"       value={<StatusBadge status={user.verification_status} />} />
                <Field label="Method"       value={cap(user.verification_method)} />
                <Field label="Request"      value={cap(user.verification_request_status)} />
                <Field label="Certificate"  value={cap(user.cert_status)} />
              </div>
              {user.verification_request_status === 'pending' && (
                <div style={{ marginTop: 14 }}>
                  <Link to="/admin/verification" className="btn btn-sm btn-primary">
                    Review Verification
                  </Link>
                </div>
              )}
            </div>
          </div>

          {(user.suspended_reason || user.banned_reason) && (
            <div className="card section-card">
              <div className="section-head">⚠ Administrative Notes</div>
              <div className="section-body">
                {user.suspended_reason && (
                  <div style={{ marginBottom: 10 }}>
                    <span className="field-label" style={{ display: 'block', marginBottom: 3 }}>Suspension reason</span>
                    <span style={{ fontSize: 13 }}>{user.suspended_reason}</span>
                    {user.suspended_at && (
                      <span style={{ fontSize: 11, color: 'var(--c-text-tertiary)', marginLeft: 8 }}>
                        {fmtDateTime(user.suspended_at)}
                      </span>
                    )}
                  </div>
                )}
                {user.banned_reason && (
                  <div>
                    <span className="field-label" style={{ display: 'block', marginBottom: 3 }}>Ban reason</span>
                    <span style={{ fontSize: 13 }}>{user.banned_reason}</span>
                    {user.banned_at && (
                      <span style={{ fontSize: 11, color: 'var(--c-text-tertiary)', marginLeft: 8 }}>
                        {fmtDateTime(user.banned_at)}
                      </span>
                    )}
                  </div>
                )}
              </div>
            </div>
          )}
        </div>

        {/* Right: admin actions */}
        <div className="card section-card">
          <div className="section-head">⚙ Admin Actions</div>
          <div className="section-body" style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {isActive && canSuspend && (
              <button className="btn btn-danger" onClick={() => setDialog('suspend')}>
                ⚠ Suspend User
              </button>
            )}
            {isActive && canBan && (
              <button className="btn btn-danger" onClick={() => setDialog('ban')}>
                ✕ Ban User
              </button>
            )}
            {(user.account_status === 'suspended' || user.account_status === 'banned') && canSuspend && (
              <button className="btn btn-success" onClick={() => setDialog('restore')}>
                ✓ Restore Account
              </button>
            )}
            {!isActive && user.account_status !== 'suspended' && user.account_status !== 'banned' && (
              <p style={{ fontSize: 12, color: 'var(--c-text-tertiary)' }}>No actions available for this account state.</p>
            )}
            {!canSuspend && !canBan && (
              <p style={{ fontSize: 12, color: 'var(--c-text-tertiary)' }}>You don't have permission to perform actions on users.</p>
            )}

            <hr className="divider" />

            <Link to="/admin/reports" className="btn btn-secondary btn-sm">
              View Reports
            </Link>
            <Link to="/admin/verification" className="btn btn-secondary btn-sm">
              View Verification Queue
            </Link>
          </div>
        </div>
      </div>

      {/* Dialogs */}
      {dialog === 'suspend' && (
        <ConfirmDialog
          title="Suspend User?"
          message="This will prevent the user from accessing the platform. They will be notified."
          confirmLabel="Suspend"
          requireReason
          reasonPlaceholder="Enter reason for suspension…"
          isLoading={acting}
          onConfirm={handleAction}
          onCancel={() => setDialog(null)}
        />
      )}
      {dialog === 'ban' && (
        <ConfirmDialog
          title="Ban User?"
          message="This will permanently ban the user from the platform. This action requires strong justification."
          confirmLabel="Ban User"
          requireReason
          reasonPlaceholder="Enter reason for ban…"
          isLoading={acting}
          onConfirm={handleAction}
          onCancel={() => setDialog(null)}
        />
      )}
      {dialog === 'restore' && (
        <ConfirmDialog
          title="Restore Account?"
          message="This will restore the user's account to active status."
          confirmLabel="Restore"
          variant="warning"
          isLoading={acting}
          onConfirm={handleAction}
          onCancel={() => setDialog(null)}
        />
      )}
    </>
  );
}

function Field({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="detail-field">
      <div className="detail-label">{label}</div>
      <div className="detail-value">{value ?? '—'}</div>
    </div>
  );
}
