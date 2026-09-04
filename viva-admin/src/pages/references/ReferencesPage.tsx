import { useEffect, useState } from 'react';
import { api } from '@/services/api';
import { useTitle } from '@/hooks/useTitle';
import type { ReferenceSummary, ReferencesResponse } from '@/types';
import { apiErrorMessage } from '@/app/AuthContext';
import StatusBadge from '@/components/StatusBadge';
import TableSkeleton from '@/components/TableSkeleton';
import ErrorAlert from '@/components/ErrorAlert';
import EmptyState from '@/components/EmptyState';
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
  const [tab, setTab]         = useState('pending');
  const [refs, setRefs]       = useState<ReferenceSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError]     = useState<string | null>(null);

  function load(t: string) {
    setLoading(true);
    setError(null);
    api.getReferences(t || undefined, 1, 50)
      .then(r => setRefs((r.data as ReferencesResponse).references ?? []))
      .catch(err => setError(apiErrorMessage(err)))
      .finally(() => setLoading(false));
  }

  useEffect(() => { load(tab); }, [tab]);

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

      <ErrorAlert message={error} onRetry={() => load(tab)} />

      <div className="card">
        <div className="table-wrap">
          {loading ? (
            <TableSkeleton rows={6} cols={5} />
          ) : refs.length === 0 ? (
            <EmptyState icon="🔗" title={`No ${tab || 'reference'} requests`} />
          ) : (
            <table className="data-table">
              <thead>
                <tr>
                  <th>User</th>
                  <th>Reference Member</th>
                  <th>Submitted</th>
                  <th>Status</th>
                  <th></th>
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
                    <td><StatusBadge status={r.status} /></td>
                    <td>
                      <Link to={`/admin/users/${r.user_id}`} className="btn btn-sm btn-secondary">
                        View User
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </>
  );
}
