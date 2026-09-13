import { useEffect, useState } from 'react';
import { api } from '@/services/api';
import { useTitle } from '@/hooks/useTitle';
import { useAuth } from '@/app/AuthContext';
import type { ReferenceSummary, ReferencesResponse } from '@/types';
import { apiErrorMessage } from '@/app/AuthContext';
import StatusBadge from '@/components/StatusBadge';
import TableSkeleton from '@/components/TableSkeleton';
import ErrorAlert from '@/components/ErrorAlert';
import EmptyState from '@/components/EmptyState';
import ConfirmDialog from '@/components/ConfirmDialog';
import { fmtDate } from '@/utils/format';
import { Link } from 'react-router-dom';

const TABS = [
  { key: '',          label: 'All' },
  { key: 'pending',   label: 'Pending' },
  { key: 'confirmed', label: 'Confirmed' },
  { key: 'rejected',  label: 'Rejected' },
  { key: 'revoked',   label: 'Revoked' },
];

export default function ReferencesPage() {
  useTitle('References');
  const { can } = useAuth();
  const [tab, setTab]               = useState('pending');
  const [refs, setRefs]             = useState<ReferenceSummary[]>([]);
  const [loading, setLoading]       = useState(true);
  const [error, setError]           = useState<string | null>(null);
  const [actionOk, setActionOk]     = useState<string | null>(null);
  const [actionErr, setActionErr]   = useState<string | null>(null);
  const [acting, setActing]         = useState(false);

  // Dialog state — which reference + which action
  const [dialog, setDialog] = useState<{ id: string; type: 'approve' | 'reject' } | null>(null);

  function load(t: string) {
    setLoading(true);
    setError(null);
    setActionOk(null);
    setActionErr(null);
    api.getReferences(t || undefined, 1, 50)
      .then(r => setRefs((r.data as ReferencesResponse).references ?? []))
      .catch(err => setError(apiErrorMessage(err)))
      .finally(() => setLoading(false));
  }

  useEffect(() => { load(tab); }, [tab]);

  async function handleAction(reason?: string) {
    if (!dialog) return;
    setActing(true);
    setActionErr(null);
    try {
      if (dialog.type === 'approve') {
        await api.approveReference(dialog.id);
        setActionOk('Reference approved. User is now verified.');
      } else {
        await api.rejectReference(dialog.id, reason ?? '');
        setActionOk('Reference rejected. User has been notified.');
      }
      setDialog(null);
      load(tab);
    } catch (err) {
      setActionErr(apiErrorMessage(err));
    } finally {
      setActing(false);
    }
  }

  const canVerify = can('verify');

  return (
    <>
      <div className="page-header">
        <div>
          <h1 className="page-title">Member References</h1>
          <p className="page-subtitle">Reference-based verification requests</p>
        </div>
      </div>

      <div className="tabs">
        {TABS.map(t => (
          <button
            key={t.key}
            className={`tab${tab === t.key ? ' active' : ''}`}
            onClick={() => setTab(t.key)}
          >
            {t.label}
          </button>
        ))}
      </div>

      {actionOk && (
        <div className="alert alert-success" style={{ marginBottom: 16 }}>✓ {actionOk}</div>
      )}
      <ErrorAlert message={error} onRetry={() => load(tab)} />
      <ErrorAlert message={actionErr} />

      <div className="card">
        <div className="table-wrap">
          {loading ? (
            <TableSkeleton rows={6} cols={6} />
          ) : refs.length === 0 ? (
            <EmptyState icon="🔗" title={`No ${tab || 'reference'} requests`} />
          ) : (
            <table className="data-table">
              <thead>
                <tr>
                  <th>User</th>
                  <th>Reference Member</th>
                  <th>Submitted</th>
                  <th>Confirmed</th>
                  <th>Status</th>
                  {canVerify && <th>Actions</th>}
                </tr>
              </thead>
              <tbody>
                {refs.map(r => (
                  <tr key={r.id}>
                    <td>
                      <Link to={`/admin/users/${r.user_id}`} style={{ fontWeight: 500 }}>
                        {r.user_name ?? r.user_id.slice(0, 8) + '…'}
                      </Link>
                    </td>
                    <td>
                      <Link to={`/admin/users/${r.reference_user_id}`} style={{ color: 'var(--c-text-secondary)' }}>
                        {r.reference_name ?? r.reference_user_id.slice(0, 8) + '…'}
                      </Link>
                    </td>
                    <td style={{ color: 'var(--c-text-secondary)' }}>{fmtDate(r.created_at)}</td>
                    <td style={{ color: 'var(--c-text-secondary)' }}>{r.confirmed_at ? fmtDate(r.confirmed_at) : '—'}</td>
                    <td><StatusBadge status={r.status} /></td>
                    {canVerify && (
                      <td>
                        <div style={{ display: 'flex', gap: 6 }}>
                          {r.status === 'pending' && (
                            <>
                              <button
                                className="btn btn-sm btn-success"
                                onClick={() => setDialog({ id: r.id, type: 'approve' })}
                              >
                                ✓ Approve
                              </button>
                              <button
                                className="btn btn-sm btn-danger"
                                onClick={() => setDialog({ id: r.id, type: 'reject' })}
                              >
                                ✕ Reject
                              </button>
                            </>
                          )}
                          {r.status !== 'pending' && (
                            <Link to={`/admin/users/${r.user_id}`} className="btn btn-sm btn-secondary">
                              View User
                            </Link>
                          )}
                        </div>
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>

      {/* Approve dialog */}
      {dialog?.type === 'approve' && (
        <ConfirmDialog
          title="Approve Reference?"
          message="This will confirm the reference and mark the user's profile as verified. The user will be notified."
          confirmLabel="Approve & Verify"
          variant="warning"
          isLoading={acting}
          onConfirm={handleAction}
          onCancel={() => setDialog(null)}
        />
      )}

      {/* Reject dialog */}
      {dialog?.type === 'reject' && (
        <ConfirmDialog
          title="Reject Reference?"
          message="The user will be notified and asked to provide a different reference."
          confirmLabel="Reject"
          requireReason
          reasonPlaceholder="Enter reason for rejection…"
          isLoading={acting}
          onConfirm={handleAction}
          onCancel={() => setDialog(null)}
        />
      )}
    </>
  );
}
