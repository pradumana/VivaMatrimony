import { useEffect, useState } from 'react';
import { api } from '@/services/api';
import { useTitle } from '@/hooks/useTitle';
import { useAuth } from '@/app/AuthContext';
import { apiErrorMessage } from '@/app/AuthContext';
import ErrorAlert from '@/components/ErrorAlert';
import Spinner from '@/components/Spinner';

export default function SettingsPage() {
  useTitle('Settings');
  const { admin } = useAuth();
  const isSuperAdmin = admin?.role === 'super_admin';

  const [settings, setSettings]   = useState<Record<string, unknown> | null>(null);
  const [loading, setLoading]     = useState(true);
  const [error, setError]         = useState<string | null>(null);
  const [saving, setSaving]       = useState(false);
  const [saveOk, setSaveOk]       = useState(false);

  useEffect(() => {
    if (!isSuperAdmin) { setLoading(false); return; }
    api.getSettings()
      .then(r => setSettings(r.data as Record<string, unknown>))
      .catch(err => setError(apiErrorMessage(err)))
      .finally(() => setLoading(false));
  }, [isSuperAdmin]);

  async function handleSave() {
    if (!settings) return;
    setSaving(true);
    setSaveOk(false);
    try {
      await api.updateSettings(settings);
      setSaveOk(true);
      setTimeout(() => setSaveOk(false), 3000);
    } catch (err) {
      setError(apiErrorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  return (
    <>
      <div className="page-header">
        <h1 className="page-title">Settings</h1>
      </div>

      {/* Account info — always shown */}
      <div className="card section-card" style={{ maxWidth: 540, marginBottom: 16 }}>
        <div className="section-head">👤 My Account</div>
        <div className="section-body">
          <div className="detail-grid">
            <div className="detail-field">
              <div className="detail-label">Name</div>
              <div className="detail-value">{admin?.full_name ?? '—'}</div>
            </div>
            <div className="detail-field">
              <div className="detail-label">Email</div>
              <div className="detail-value">{admin?.email ?? '—'}</div>
            </div>
            <div className="detail-field">
              <div className="detail-label">Role</div>
              <div className="detail-value">
                <span className="badge badge-verified">{admin?.role?.replace('_', ' ')}</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Super admin: platform settings */}
      {isSuperAdmin && (
        <div className="card section-card" style={{ maxWidth: 540 }}>
          <div className="section-head">⚙ Platform Settings</div>
          <div className="section-body">
            {loading && (
              <div style={{ display: 'flex', gap: 8, alignItems: 'center', color: 'var(--c-text-secondary)' }}>
                <Spinner size={16} /> Loading…
              </div>
            )}

            <ErrorAlert message={error} />

            {saveOk && (
              <div className="alert alert-success" style={{ marginBottom: 12 }}>✓ Settings saved.</div>
            )}

            {!loading && settings && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
                {Object.entries(settings).map(([key, value]) => (
                  <div key={key}>
                    <label className="field-label" htmlFor={`setting-${key}`}>
                      {key.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())}
                    </label>
                    {typeof value === 'boolean' ? (
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <input
                          id={`setting-${key}`}
                          type="checkbox"
                          checked={value}
                          onChange={e => setSettings(s => s ? { ...s, [key]: e.target.checked } : s)}
                        />
                        <span style={{ fontSize: 13 }}>{value ? 'Enabled' : 'Disabled'}</span>
                      </div>
                    ) : (
                      <input
                        id={`setting-${key}`}
                        className="input"
                        value={String(value)}
                        onChange={e => setSettings(s => s ? { ...s, [key]: e.target.value } : s)}
                      />
                    )}
                  </div>
                ))}
                <div style={{ marginTop: 4 }}>
                  <button
                    className="btn btn-primary"
                    onClick={handleSave}
                    disabled={saving}
                  >
                    {saving ? 'Saving…' : 'Save Settings'}
                  </button>
                </div>
              </div>
            )}

            {!loading && !settings && !error && (
              <div style={{ fontSize: 13, color: 'var(--c-text-tertiary)' }}>
                No configurable settings are exposed by the backend.
              </div>
            )}
          </div>
        </div>
      )}

      {!isSuperAdmin && (
        <div className="alert alert-info" style={{ maxWidth: 540 }}>
          ℹ Platform settings are only accessible to Super Admins.
        </div>
      )}
    </>
  );
}
