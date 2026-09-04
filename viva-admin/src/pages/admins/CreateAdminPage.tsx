import { type FormEvent, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { api } from '@/services/api';
import { useTitle } from '@/hooks/useTitle';
import { apiErrorMessage } from '@/app/AuthContext';
import ErrorAlert from '@/components/ErrorAlert';
import type { AdminRole } from '@/types';

export default function CreateAdminPage() {
  useTitle('Create Admin');
  const navigate = useNavigate();
  const [fullName, setFullName] = useState('');
  const [email, setEmail]       = useState('');
  const [role, setRole]         = useState<AdminRole>('admin');
  const [password, setPassword] = useState('');
  const [loading, setLoading]   = useState(false);
  const [error, setError]       = useState<string | null>(null);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (password.length < 8) {
      setError('Password must be at least 8 characters.');
      return;
    }
    setLoading(true);
    setError(null);
    try {
      await api.createAdmin({ full_name: fullName, email, role, password });
      navigate('/admin/admins');
    } catch (err) {
      setError(apiErrorMessage(err));
    } finally {
      setLoading(false);
    }
  }

  return (
    <>
      <div className="page-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <Link to="/admin/admins" className="btn btn-ghost btn-sm">‹ Admins</Link>
          <h1 className="page-title">Create Admin</h1>
        </div>
      </div>

      <div style={{ maxWidth: 480 }}>
        <div className="card" style={{ padding: '24px' }}>
          <ErrorAlert message={error} />

          <form onSubmit={handleSubmit} noValidate style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div>
              <label className="field-label" htmlFor="fullName">Full Name</label>
              <input
                id="fullName"
                className="input"
                value={fullName}
                onChange={e => setFullName(e.target.value)}
                required
                placeholder="Admin Full Name"
                disabled={loading}
              />
            </div>

            <div>
              <label className="field-label" htmlFor="email">Email</label>
              <input
                id="email"
                type="email"
                className="input"
                value={email}
                onChange={e => setEmail(e.target.value)}
                required
                placeholder="admin@viva.app"
                disabled={loading}
                autoComplete="off"
              />
            </div>

            <div>
              <label className="field-label" htmlFor="role">Role</label>
              <select
                id="role"
                className="input"
                value={role}
                onChange={e => setRole(e.target.value as AdminRole)}
                disabled={loading}
              >
                <option value="support">Support</option>
                <option value="moderator">Moderator</option>
                <option value="admin">Admin</option>
                <option value="super_admin">Super Admin</option>
              </select>
            </div>

            <div>
              <label className="field-label" htmlFor="password">Temporary Password</label>
              <input
                id="password"
                type="password"
                className="input"
                value={password}
                onChange={e => setPassword(e.target.value)}
                required
                placeholder="Min 8 characters"
                disabled={loading}
                autoComplete="new-password"
              />
              <p style={{ fontSize: 11, color: 'var(--c-text-tertiary)', marginTop: 4 }}>
                The admin should change this immediately after first login.
              </p>
            </div>

            <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end', marginTop: 4 }}>
              <Link to="/admin/admins" className="btn btn-secondary">Cancel</Link>
              <button
                type="submit"
                className="btn btn-primary"
                disabled={loading || !fullName || !email || !password}
              >
                {loading ? 'Creating…' : 'Create Admin'}
              </button>
            </div>
          </form>
        </div>
      </div>
    </>
  );
}
