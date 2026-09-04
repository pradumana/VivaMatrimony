import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '@/services/api';
import { useTitle } from '@/hooks/useTitle';
import type { DashboardStats, CertificateSummary } from '@/types';
import { apiErrorMessage } from '@/app/AuthContext';
import ErrorAlert from '@/components/ErrorAlert';
import { fmtDate } from '@/utils/format';

export default function DashboardPage() {
  useTitle('Dashboard');
  const [stats, setStats]       = useState<DashboardStats | null>(null);
  const [certs, setCerts]       = useState<CertificateSummary[]>([]);
  const [loading, setLoading]   = useState(true);
  const [error, setError]       = useState<string | null>(null);

  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        const [sRes, cRes] = await Promise.all([
          api.getDashboard(),
          api.getCertificates('pending', 1, 5),
        ]);
        if (!mounted) return;
        setStats(sRes.data as DashboardStats);
        setCerts((cRes.data as { certificates: CertificateSummary[] }).certificates);
      } catch (err) {
        if (mounted) setError(apiErrorMessage(err));
      } finally {
        if (mounted) setLoading(false);
      }
    })();
    return () => { mounted = false; };
  }, []);

  return (
    <>
      <div className="page-header">
        <div>
          <h1 className="page-title">Dashboard</h1>
          <p className="page-subtitle">Platform overview</p>
        </div>
      </div>

      <ErrorAlert message={error} />

      {/* Stat cards */}
      <div className="stat-grid">
        <StatCard label="Total Users"        value={stats?.total_users}         loading={loading} />
        <StatCard label="New This Week"      value={stats?.new_users_week}      loading={loading} />
        <StatCard label="Active Today"       value={stats?.active_today}        loading={loading} />
        <StatCard label="Verified Users"     value={stats?.verified_users}      loading={loading} />
        <StatCard label="Pending Verify"     value={stats?.pending_verification} loading={loading} highlight />
        <StatCard label="Pending Certs"      value={stats?.pending_certificates} loading={loading} highlight />
        <StatCard label="Open Reports"       value={stats?.open_reports}        loading={loading} highlight />
        <StatCard label="Interests / Week"   value={stats?.interests_week}      loading={loading} />
      </div>

      {/* Pending certificates quick list */}
      <div className="card section-card">
        <div className="section-head">
          📄 Pending Certificate Reviews
          {certs.length > 0 && (
            <Link
              to="/admin/verification?tab=pending"
              className="btn btn-sm btn-secondary"
              style={{ marginLeft: 'auto' }}
            >
              View all
            </Link>
          )}
        </div>
        <div className="section-body" style={{ padding: 0 }}>
          {loading ? (
            <div style={{ padding: '16px 18px' }}>
              {[1,2,3].map(i => (
                <div key={i} className="skeleton" style={{ height: 14, marginBottom: 10, width: `${60 + i * 10}%` }} />
              ))}
            </div>
          ) : certs.length === 0 ? (
            <div style={{ padding: '24px 18px', textAlign: 'center', color: 'var(--c-text-tertiary)', fontSize: 13 }}>
              ✓ No pending certificates
            </div>
          ) : (
            <table className="data-table">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>File</th>
                  <th>Submitted</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {certs.map(c => (
                  <tr key={c.document_id}>
                    <td style={{ fontWeight: 500 }}>{c.full_name}</td>
                    <td style={{ color: 'var(--c-text-secondary)', fontSize: 12 }}>{c.file_name}</td>
                    <td style={{ color: 'var(--c-text-secondary)' }}>{fmtDate(c.created_at)}</td>
                    <td>
                      <Link
                        to={`/admin/verification/${c.document_id}`}
                        className="btn btn-sm btn-primary"
                      >
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

function StatCard({
  label, value, loading, highlight,
}: {
  label: string;
  value: number | undefined;
  loading: boolean;
  highlight?: boolean;
}) {
  return (
    <div className={`stat-card${highlight && value ? ' highlight' : ''}`}>
      <div className="stat-label">{label}</div>
      {loading ? (
        <div className="skeleton" style={{ height: 28, width: 60, marginTop: 4 }} />
      ) : (
        <div className="stat-value">{value?.toLocaleString('en-IN') ?? '—'}</div>
      )}
    </div>
  );
}
