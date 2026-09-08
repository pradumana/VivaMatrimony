import { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { api } from '@/services/api';
import { useTitle } from '@/hooks/useTitle';
import type { PhotoSummary, PhotosResponse } from '@/types';
import { apiErrorMessage } from '@/app/AuthContext';
import ConfirmDialog from '@/components/ConfirmDialog';
import ErrorAlert from '@/components/ErrorAlert';
import EmptyState from '@/components/EmptyState';
import Spinner from '@/components/Spinner';

const TABS = [
  { key: 'pending',  label: 'All Photos' },
  { key: 'flagged',  label: 'Flagged' },
];

type Action = { type: 'flag'; photo: PhotoSummary } | { type: 'approve'; photo: PhotoSummary } | null;

export default function PhotosPage() {
  useTitle('Photo Moderation');
  const [searchParams, setSearchParams] = useSearchParams();
  const activeTab = searchParams.get('tab') ?? 'pending';

  const [photos, setPhotos]   = useState<PhotoSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError]     = useState<string | null>(null);
  const [action, setAction]   = useState<Action>(null);
  const [acting, setActing]   = useState(false);
  const [actErr, setActErr]   = useState<string | null>(null);
  const [flagReason, setFlagReason] = useState('');

  function load(tab: string) {
    setLoading(true);
    setError(null);
    api.getPhotos(tab, 1, 50)
      .then(r => setPhotos((r.data as PhotosResponse).photos))
      .catch(err => setError(apiErrorMessage(err)))
      .finally(() => setLoading(false));
  }

  useEffect(() => { load(activeTab); }, [activeTab]);

  async function handleConfirm(reason?: string) {
    if (!action) return;
    setActing(true);
    setActErr(null);
    try {
      if (action.type === 'approve') {
        await api.approvePhoto(action.photo.photo_id);
      } else {
        await api.flagPhoto(action.photo.photo_id, flagReason || reason || undefined);
      }
      setAction(null);
      setFlagReason('');
      load(activeTab);
    } catch (err) {
      setActErr(apiErrorMessage(err));
    } finally {
      setActing(false);
    }
  }

  return (
    <>
      <div className="page-header">
        <div>
          <h1 className="page-title">Photo Moderation</h1>
          <p className="page-subtitle">Review and moderate member profile photos</p>
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

      {loading ? (
        <div style={{ display: 'flex', justifyContent: 'center', padding: 48 }}>
          <Spinner size={32} />
        </div>
      ) : photos.length === 0 ? (
        <EmptyState icon="🖼" title={`No ${activeTab} photos`} />
      ) : (
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))',
          gap: 16,
          padding: '4px 0',
        }}>
          {photos.map(p => (
            <div key={p.photo_id} className="card" style={{ padding: 0, overflow: 'hidden' }}>
              {/* Photo */}
              <div style={{ position: 'relative', width: '100%', paddingBottom: '125%', background: 'var(--c-bg)' }}>
                {p.signed_url ? (
                  <img
                    src={p.signed_url}
                    alt={p.full_name}
                    style={{
                      position: 'absolute', inset: 0,
                      width: '100%', height: '100%',
                      objectFit: 'cover',
                    }}
                    loading="lazy"
                  />
                ) : (
                  <div style={{
                    position: 'absolute', inset: 0,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontSize: 32, color: 'var(--c-text-secondary)',
                  }}>🖼</div>
                )}
                {p.is_primary && (
                  <span style={{
                    position: 'absolute', top: 6, left: 6,
                    background: 'var(--c-gold)', color: '#fff',
                    fontSize: 10, fontWeight: 700,
                    padding: '2px 6px', borderRadius: 4,
                  }}>PRIMARY</span>
                )}
                {p.is_flagged && (
                  <span style={{
                    position: 'absolute', top: 6, right: 6,
                    background: 'var(--c-red)', color: '#fff',
                    fontSize: 10, fontWeight: 700,
                    padding: '2px 6px', borderRadius: 4,
                  }}>FLAGGED</span>
                )}
              </div>

              {/* Info + actions */}
              <div style={{ padding: '10px 12px' }}>
                <p style={{ fontWeight: 600, fontSize: 13, marginBottom: 2 }}>{p.full_name}</p>
                {p.flag_reason && (
                  <p style={{ fontSize: 11, color: 'var(--c-red)', marginBottom: 6 }}>
                    {p.flag_reason}
                  </p>
                )}
                <div style={{ display: 'flex', gap: 6, marginTop: 8 }}>
                  {p.is_flagged ? (
                    <button
                      className="btn btn-sm btn-primary"
                      style={{ flex: 1 }}
                      onClick={() => setAction({ type: 'approve', photo: p })}
                    >
                      Restore
                    </button>
                  ) : (
                    <button
                      className="btn btn-sm btn-danger"
                      style={{ flex: 1 }}
                      onClick={() => { setFlagReason(''); setAction({ type: 'flag', photo: p }); }}
                    >
                      Flag
                    </button>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Approve/restore dialog */}
      {action?.type === 'approve' && (
        <ConfirmDialog
          title="Restore Photo"
          message={`Restore this photo for ${action.photo.full_name}? It will become visible again.`}
          confirmLabel="Restore"
          variant="warning"
          onConfirm={handleConfirm}
          onCancel={() => setAction(null)}
          isLoading={acting}
        />
      )}

      {/* Flag dialog with reason input */}
      {action?.type === 'flag' && (
        <div style={{
          position: 'fixed', inset: 0, background: 'rgba(0,0,0,.5)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 200,
        }}>
          <div className="card" style={{ width: 400, padding: 24 }}>
            <h3 style={{ marginBottom: 12 }}>Flag Photo</h3>
            <p style={{ fontSize: 13, color: 'var(--c-text-secondary)', marginBottom: 16 }}>
              This will hide the photo and notify the user. Optionally add a reason.
            </p>
            <textarea
              className="input"
              placeholder="Reason (optional)"
              rows={3}
              value={flagReason}
              onChange={e => setFlagReason(e.target.value)}
              style={{ width: '100%', resize: 'vertical', marginBottom: 16 }}
            />
            {actErr && <p style={{ color: 'var(--c-red)', fontSize: 13, marginBottom: 12 }}>{actErr}</p>}
            <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
              <button className="btn btn-ghost" onClick={() => setAction(null)} disabled={acting}>
                Cancel
              </button>
              <button className="btn btn-danger" onClick={handleConfirm} disabled={acting}>
                {acting ? <Spinner size={16} /> : 'Flag Photo'}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
