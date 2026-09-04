import { useEffect, useRef, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { api } from '@/services/api';
import { useTitle } from '@/hooks/useTitle';
import type { CertificateSummary, SignedUrlResponse } from '@/types';
import { apiErrorMessage } from '@/app/AuthContext';
import StatusBadge from '@/components/StatusBadge';
import ConfirmDialog from '@/components/ConfirmDialog';
import ErrorAlert from '@/components/ErrorAlert';
import Spinner from '@/components/Spinner';
import { fmtDateTime } from '@/utils/format';

type Dialog = 'approve' | 'reject' | null;

export default function VerificationDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [cert, setCert]             = useState<CertificateSummary | null>(null);
  const [loading, setLoading]       = useState(true);
  const [error, setError]           = useState<string | null>(null);
  const [docUrl, setDocUrl]         = useState<string | null>(null);
  const [docLoading, setDocLoading] = useState(false);
  const [docError, setDocError]     = useState<string | null>(null);
  const [dialog, setDialog]         = useState<Dialog>(null);
  const [acting, setActing]         = useState(false);
  const [actionErr, setActionErr]   = useState<string | null>(null);
  // Prevent double-clicks
  const inFlight = useRef(false);

  useTitle('Certificate Review');

  useEffect(() => {
    if (!id) return;
    setLoading(true);
    // Fetch list and find the cert — backend has no single-cert GET; use list
    api.getCertificates('pending', 1, 100)
      .then(r => {
        const all = (r.data as { certificates: CertificateSummary[] }).certificates;
        const found = all.find(c => c.document_id === id);
        if (!found) {
          // Try approved/rejected
          return Promise.all([
            api.getCertificates('approved', 1, 100),
            api.getCertificates('rejected', 1, 100),
          ]).then(([a, b]) => {
            const combined = [
              ...(a.data as { certificates: CertificateSummary[] }).certificates,
              ...(b.data as { certificates: CertificateSummary[] }).certificates,
            ];
            return combined.find(c => c.document_id === id) ?? null;
          });
        }
        return found;
      })
      .then(c => { if (c) setCert(c as CertificateSummary); else setError('Certificate not found.'); })
      .catch(err => setError(apiErrorMessage(err)))
      .finally(() => setLoading(false));
  }, [id]);

  async function loadDocument() {
    if (!id) return;
    setDocLoading(true);
    setDocError(null);
    setDocUrl(null);
    try {
      const r = await api.viewCertificate(id);
      const data = r.data as SignedUrlResponse;
      setDocUrl(data.signed_url);
      // Auto-expire the URL reference after 5 min (server already expires it)
      setTimeout(() => setDocUrl(null), 5 * 60 * 1000);
    } catch (err) {
      setDocError(apiErrorMessage(err));
    } finally {
      setDocLoading(false);
    }
  }

  async function handleAction(reason?: string) {
    if (!id || !dialog || inFlight.current) return;
    inFlight.current = true;
    setActing(true);
    setActionErr(null);
    try {
      if (dialog === 'approve') await api.approveCertificate(id);
      if (dialog === 'reject')  await api.rejectCertificate(id, reason ?? '');
      setDialog(null);
      navigate('/admin/verification?tab=' + (dialog === 'approve' ? 'approved' : 'rejected'));
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
      <Link to="/admin/verification" className="btn btn-ghost btn-sm" style={{ marginBottom: 12 }}>‹ Back</Link>
      <ErrorAlert message={error} />
    </div>
  );

  const isProcessed = cert?.status !== 'pending';

  return (
    <>
      <div className="page-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <Link to="/admin/verification" className="btn btn-ghost btn-sm">‹ Verification</Link>
          <h1 className="page-title">Certificate Review</h1>
          {cert && <StatusBadge status={cert.status} />}
        </div>
      </div>

      <ErrorAlert message={actionErr} />

      {isProcessed && (
        <div className="alert alert-info" style={{ marginBottom: 16 }}>
          ℹ This certificate has already been {cert?.status}. No further action required.
        </div>
      )}

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 300px', gap: 16, alignItems: 'start' }}>
        {/* Document viewer */}
        <div>
          <div className="card section-card">
            <div className="section-head">
              📄 Document
              {cert && (
                <span style={{ fontSize: 12, color: 'var(--c-text-tertiary)', marginLeft: 8 }}>
                  {cert.file_name}
                </span>
              )}
            </div>
            <div className="section-body">
              {!docUrl ? (
                <div style={{ textAlign: 'center', padding: '24px 0' }}>
                  <p style={{ fontSize: 13, color: 'var(--c-text-secondary)', marginBottom: 14 }}>
                    Document is stored securely. Click to generate a temporary access link (expires in 5 minutes).
                  </p>
                  <ErrorAlert message={docError} />
                  <button
                    className="btn btn-primary"
                    onClick={loadDocument}
                    disabled={docLoading}
                  >
                    {docLoading ? <><Spinner size={14} /> Loading…</> : '🔒 View Document'}
                  </button>
                </div>
              ) : (
                <div>
                  <div className="alert alert-warning" style={{ marginBottom: 12 }}>
                    ⏱ This link expires in 5 minutes. Do not share it.
                  </div>
                  {/* Render PDF inline or open in new tab */}
                  {docUrl.includes('.pdf') || cert?.file_name?.endsWith('.pdf') ? (
                    <div style={{ textAlign: 'center' }}>
                      <iframe
                        src={docUrl}
                        style={{ width: '100%', height: 500, border: 'none', borderRadius: 6 }}
                        title="Certificate document"
                      />
                    </div>
                  ) : (
                    <img
                      src={docUrl}
                      alt="Certificate document"
                      style={{ maxWidth: '100%', borderRadius: 6, display: 'block' }}
                    />
                  )}
                  <div style={{ marginTop: 10, display: 'flex', gap: 8 }}>
                    <a
                      href={docUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="btn btn-secondary btn-sm"
                    >
                      Open in new tab ↗
                    </a>
                    <button className="btn btn-ghost btn-sm" onClick={() => setDocUrl(null)}>
                      Close
                    </button>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Right panel */}
        <div>
          <div className="card section-card" style={{ marginBottom: 12 }}>
            <div className="section-head">👤 Member</div>
            <div className="section-body">
              <div style={{ fontSize: 15, fontWeight: 600, marginBottom: 6 }}>{cert?.full_name ?? '—'}</div>
              <div style={{ fontSize: 12, color: 'var(--c-text-secondary)' }}>
                Submitted: {fmtDateTime(cert?.created_at)}
              </div>
              {cert?.user_id && (
                <div style={{ marginTop: 10 }}>
                  <Link to={`/admin/users/${cert.user_id}`} className="btn btn-secondary btn-sm">
                    View Profile
                  </Link>
                </div>
              )}
            </div>
          </div>

          {!isProcessed && (
            <div className="card section-card">
              <div className="section-head">⚙ Decision</div>
              <div className="section-body" style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                <button className="btn btn-success" onClick={() => setDialog('approve')}>
                  ✓ Approve
                </button>
                <button className="btn btn-danger" onClick={() => setDialog('reject')}>
                  ✕ Reject
                </button>
              </div>
            </div>
          )}
        </div>
      </div>

      {dialog === 'approve' && (
        <ConfirmDialog
          title="Approve Certificate?"
          message="This will mark the user as verified and notify them. This action cannot be undone."
          confirmLabel="Approve"
          variant="warning"
          isLoading={acting}
          onConfirm={handleAction}
          onCancel={() => setDialog(null)}
        />
      )}
      {dialog === 'reject' && (
        <ConfirmDialog
          title="Reject Certificate?"
          message="The user will be notified with the reason provided. They can re-upload."
          confirmLabel="Reject"
          requireReason
          reasonPlaceholder="e.g. Document is unclear / could not be verified…"
          isLoading={acting}
          onConfirm={handleAction}
          onCancel={() => setDialog(null)}
        />
      )}
    </>
  );
}
