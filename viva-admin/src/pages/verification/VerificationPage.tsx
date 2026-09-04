import { useEffect, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { api } from '@/services/api';
import { useTitle } from '@/hooks/useTitle';
import type { CertificateSummary } from '@/types';
import { apiErrorMessage } from '@/app/AuthContext';
import StatusBadge from '@/components/StatusBadge';
import TableSkeleton from '@/components/TableSkeleton';
import ErrorAlert from '@/components/ErrorAlert';
import EmptyState from '@/components/EmptyState';
import { fmtDate } from '@/utils/format';

const TABS = [
  { key: 'pending',  label: 'Pending' },
  { key: 'approved', label: 'Approved' },
  { key: 'rejected', label: 'Rejected' },
];

export default function VerificationPage() {
  useTitle('Verification');
  const [searchParams, setSearchParams] = useSearchParams();
  const activeTab = searchParams.get('tab') ?? 'pending';

  const [certs, setCerts]     = useState<CertificateSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError]     = useState<string | null>(null);

  function load(tab: string) {
    setLoading(true);
    setError(null);
    api.getCertificates(tab, 1, 50)
      .then(r => setCerts((r.data as { certificates: CertificateSummary[] }).certificates))
      .catch(err => setError(apiErrorMessage(err)))
      .finally(() => setLoading(false));
  }

  useEffect(() => { load(activeTab); }, [activeTab]);

  return (
    <>
      <div className="page-header">
        <div>
          <h1 className="page-title">Certificate Verification</h1>
          <p className="page-subtitle">Review caste certificates submitted by members</p>
        </div>
      </div>

      <div className="tabs">
        {TABS.map(t => (
          <button
            key={t.key}
            className={`tab${activeTab === t.key ? ' active' : ''}`}
            onClick={() => setSearchParams({ tab: t.key })}
          >
            {t.label}
          </button>
        ))}
      </div>

      <ErrorAlert message={error} onRetry={() => load(activeTab)} />

      <div className="card">
        <div className="table-wrap">
          {loading ? (
            <TableSkeleton rows={6} cols={5} />
          ) : certs.length === 0 ? (
            <EmptyState icon="✓" title={`No ${activeTab} certificates`} />
          ) : (
            <table className="data-table">
              <thead>
                <tr>
                  <th>Member</th>
                  <th>File Name</th>
                  <th>Submitted</th>
                  <th>Status</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {certs.map(c => (
                  <tr key={c.document_id}>
                    <td style={{ fontWeight: 500 }}>{c.full_name}</td>
                    <td style={{ fontSize: 12, color: 'var(--c-text-secondary)', maxWidth: 200 }} className="truncate">
                      {c.file_name}
                    </td>
                    <td style={{ color: 'var(--c-text-secondary)' }}>{fmtDate(c.created_at)}</td>
                    <td><StatusBadge status={c.status} /></td>
                    <td>
                      <Link to={`/admin/verification/${c.document_id}`} className="btn btn-sm btn-primary">
                        Review
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
