import { useEffect, useRef, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { api } from '@/services/api';
import { useTitle } from '@/hooks/useTitle';
import { useAuth } from '@/app/AuthContext';
import type { ReportSummary, ReportsResponse } from '@/types';
import { apiErrorMessage } from '@/app/AuthContext';
import StatusBadge from '@/components/StatusBadge';
import ConfirmDialog from '@/components/ConfirmDialog';
import ErrorAlert from '@/components/ErrorAlert';
import Spinner from '@/components/Spinner';
import { cap, fmtDateTime } from '@/utils/format';

type Dialog = 'resolve' | 'dismiss' | 'suspend' | 'ban' | null;

export default function ReportDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { can } = useAuth();
  const [report, setReport]     = useState<ReportSummary | null>(null);
  const [loading, setLoading]   = useState(true);
  const [error, setError]       = useState<string | null>(null);
  const [dialog, setDialog]     = useState<Dialog>(null);
  const [acting, setActing]     = useState(false);
  const [actionErr, setActionErr] = useState<string | null>(null);
  const inFlight = useRef(false);

  useTitle('Report Detail');

  function load() {
    if (!id) return;
    setLoading(true);
    setError(null);
    // Fetch from all statuses
    Promise.all([
      api.getReports('open', 1, 200),
      api.getReports('under_review', 1, 200),
      api.getReports('resolved', 1, 200),
      api.getReports('dismissed', 1, 200),
    ])
      .then(results => {
        const all = results.flatMap(r => (r.data as ReportsResponse).reports);
        const found = all.find(r => r.id === id);
        if (found) setReport(found);
        else setError('Report not found.');
      })
      .catch(err => setError(apiErrorMessage(err)))
      .finally(() => setLoading(false));
  }

  useEffect(load, [id]);

  async function handleAction(reason?: string) {
    if (!id || !dialog || inFlight.current) return;
    inFlight.current = true;
    setActing(true);
    setActionErr(null);
    try {
      if (dialog === 'resolve')  await api.resolveReport(id, reason ?? 'Resolved by admin.');
      if (dialog === 'dismiss')  await api.dismissReport(id, reason ?? 'Dismissed by admin.');
      if (dialog === 'suspend' && report)
        await api.suspendUser(report.reported_id, reason ?? 'User suspended following report review.');
      if (dialog === 'ban' && report)
        await api.banUser(report.reported_id, reason ?? 'User banned following report review.');
      setDialog(null);
      navigate('/admin/reports');
    } catch (err) {
      setActionErr(apiErrorMessage(err));
    } finally {
      setActing(false);
      inFlight.current = false;
    }
  }

  if (loading) return (
    <div style={{ display: 'flex', gap: 12, padding: 32, alignItems: 'center' }}>
      <Spinner /> <span style={{ color: 'var(--c-text-secondary)' }}>Loading…</span>
    </div>
  );

  if (error) return (
    <div style={{ padding: 16 }}>
      <Link to="/admin/reports" className="btn btn-ghost btn-sm" style={{ marginBottom: 12 }}>‹ Back</Link>
      <ErrorAlert message={error} />
    </div>
  );

  if (!report) return null;

  const isOpen = report.status === 'open' || report.status === 'under_review';

  return (
    <>
      <div className="page-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <Link to="/admin/reports" className="btn btn-ghost btn-sm">‹ Reports</Link>
          <h1 className="page-title">Report Detail</h1>
          <StatusBadge status={report.status} />
        </div>
      </div>

      <ErrorAlert message={actionErr} />

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 280px', gap: 16, alignItems: 'start' }}>
        {/* Left: report info */}
        <div>
          <div className="card section-card">
            <div className="section-head">🚩 Report Details</div>
            <div className="section-body">
              <div className="detail-grid" style={{ marginBottom: 16 }}>
                <div className="detail-field">
                  <div className="detail-label">Reported User</div>
                  <div className="detail-value">
                    <Link to={`/admin/users/${report.reported_id}`}>
                      {report.reported_name ?? report.reported_id.slice(0, 8)}
                    </Link>
                  </div>
                </div>
                <div className="detail-field">
                  <div className="detail-label">Reported By</div>
                  <div className="detail-value">
                    <Link to={`/admin/users/${report.reporter_id}`}>
                      {report.reporter_name ?? report.reporter_id.slice(0, 8)}
                    </Link>
                  </div>
                </div>
                <div className="detail-field">
                  <div className="detail-label">Reason</div>
                  <div className="detail-value">
                    <span className="badge badge-pending">{cap(report.reason)}</span>
                  </div>
                </div>
                <div className="detail-field">
                  <div className="detail-label">Submitted</div>
                  <div className="detail-value">{fmtDateTime(report.created_at)}</div>
                </div>
              </div>
              {report.description && (
                <div>
                  <div className="detail-label" style={{ marginBottom: 5 }}>Description</div>
                  <div style={{
                    padding: '12px 14px', background: 'var(--c-cream)',
                    borderRadius: 'var(--radius-sm)', fontSize: 13,
                    lineHeight: 1.6, color: 'var(--c-text-primary)',
                  }}>
                    {report.description}
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Right: actions */}
        <div className="card section-card">
          <div className="section-head">⚙ Actions</div>
          <div className="section-body" style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {!isOpen ? (
              <div className="alert alert-info">
                ℹ This report has been {report.status}.
              </div>
            ) : (
              <>
                <button className="btn btn-success" onClick={() => setDialog('resolve')}>
                  ✓ Mark Resolved
                </button>
                <button className="btn btn-secondary" onClick={() => setDialog('dismiss')}>
                  — Dismiss
                </button>

                {can('suspend') && (
                  <>
                    <hr className="divider" />
                    <p style={{ fontSize: 11, color: 'var(--c-text-tertiary)' }}>
                      User actions — use only after thorough review
                    </p>
                    <button className="btn btn-danger" onClick={() => setDialog('suspend')}>
                      ⚠ Suspend Reported User
                    </button>
                    {can('ban') && (
                      <button className="btn btn-danger" onClick={() => setDialog('ban')}>
                        ✕ Ban Reported User
                      </button>
                    )}
                  </>
                )}
              </>
            )}

            <hr className="divider" />
            <Link to={`/admin/users/${report.reported_id}`} className="btn btn-secondary btn-sm">
              View Reported Profile
            </Link>
          </div>
        </div>
      </div>

      {dialog === 'resolve' && (
        <ConfirmDialog
          title="Mark as Resolved?"
          message="Add a note about how this report was handled."
          confirmLabel="Resolve"
          variant="warning"
          requireReason
          reasonPlaceholder="Resolution note…"
          isLoading={acting}
          onConfirm={handleAction}
          onCancel={() => setDialog(null)}
        />
      )}
      {dialog === 'dismiss' && (
        <ConfirmDialog
          title="Dismiss Report?"
          message="This report will be marked as dismissed."
          confirmLabel="Dismiss"
          variant="warning"
          requireReason
          reasonPlaceholder="Reason for dismissal…"
          isLoading={acting}
          onConfirm={handleAction}
          onCancel={() => setDialog(null)}
        />
      )}
      {dialog === 'suspend' && (
        <ConfirmDialog
          title="Suspend Reported User?"
          message="This will suspend the reported user's account. Requires strong justification."
          confirmLabel="Suspend"
          requireReason
          reasonPlaceholder="Reason for suspension…"
          isLoading={acting}
          onConfirm={handleAction}
          onCancel={() => setDialog(null)}
        />
      )}
      {dialog === 'ban' && (
        <ConfirmDialog
          title="Ban Reported User?"
          message="This will permanently ban the reported user. This is irreversible without admin intervention."
          confirmLabel="Ban User"
          requireReason
          reasonPlaceholder="Reason for ban…"
          isLoading={acting}
          onConfirm={handleAction}
          onCancel={() => setDialog(null)}
        />
      )}
    </>
  );
}
