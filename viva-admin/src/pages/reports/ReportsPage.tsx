import { useEffect, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { api } from '@/services/api';
import { useTitle } from '@/hooks/useTitle';
import type { ReportSummary, ReportsResponse } from '@/types';
import { apiErrorMessage } from '@/app/AuthContext';
import StatusBadge from '@/components/StatusBadge';
import TableSkeleton from '@/components/TableSkeleton';
import ErrorAlert from '@/components/ErrorAlert';
import EmptyState from '@/components/EmptyState';
import { cap, fmtDate } from '@/utils/format';

const TABS = [
  { key: 'open',         label: 'Open' },
  { key: 'under_review', label: 'Under Review' },
  { key: 'resolved',     label: 'Resolved' },
  { key: 'dismissed',    label: 'Dismissed' },
];

export default function ReportsPage() {
  useTitle('Reports');
  const [searchParams, setSearchParams] = useSearchParams();
  const activeTab = searchParams.get('status') ?? 'open';

  const [reports, setReports] = useState<ReportSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError]     = useState<string | null>(null);

  function load(status: string) {
    setLoading(true);
    setError(null);
    api.getReports(status, 1, 50)
      .then(r => setReports((r.data as ReportsResponse).reports))
      .catch(err => setError(apiErrorMessage(err)))
      .finally(() => setLoading(false));
  }

  useEffect(() => { load(activeTab); }, [activeTab]);

  return (
    <>
      <div className="page-header">
        <div>
          <h1 className="page-title">Reports</h1>
          <p className="page-subtitle">User-submitted profile reports</p>
        </div>
      </div>

      <div className="tabs">
        {TABS.map(t => (
          <button
            key={t.key}
            className={`tab${activeTab === t.key ? ' active' : ''}`}
            onClick={() => setSearchParams({ status: t.key })}
          >
            {t.label}
          </button>
        ))}
      </div>

      <ErrorAlert message={error} onRetry={() => load(activeTab)} />

      <div className="card">
        <div className="table-wrap">
          {loading ? (
            <TableSkeleton rows={6} cols={6} />
          ) : reports.length === 0 ? (
            <EmptyState icon="🚩" title={`No ${activeTab.replace('_', ' ')} reports`} />
          ) : (
            <table className="data-table">
              <thead>
                <tr>
                  <th>Reported</th>
                  <th>Reporter</th>
                  <th>Reason</th>
                  <th>Created</th>
                  <th>Status</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {reports.map(r => (
                  <tr key={r.id}>
                    <td>
                      <Link to={`/admin/users/${r.reported_id}`} style={{ fontWeight: 500 }}>
                        {r.reported_name ?? '—'}
                      </Link>
                    </td>
                    <td style={{ color: 'var(--c-text-secondary)' }}>{r.reporter_name ?? '—'}</td>
                    <td>
                      <span className="badge badge-pending" style={{ fontSize: 11 }}>
                        {cap(r.reason)}
                      </span>
                    </td>
                    <td style={{ color: 'var(--c-text-secondary)' }}>{fmtDate(r.created_at)}</td>
                    <td><StatusBadge status={r.status} /></td>
                    <td>
                      <Link to={`/admin/reports/${r.id}`} className="btn btn-sm btn-primary">
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
