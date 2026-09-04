import { type FormEvent, useState } from 'react';
import { useAuth, apiErrorMessage } from '@/app/AuthContext';
import { useTitle } from '@/hooks/useTitle';

export default function LoginPage() {
  useTitle('Login');
  const { login } = useAuth();
  const [email, setEmail]       = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading]   = useState(false);
  const [error, setError]       = useState<string | null>(null);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      await login(email.trim().toLowerCase(), password);
    } catch (err) {
      setError(apiErrorMessage(err));
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={{
      minHeight: '100vh', display: 'flex', alignItems: 'center',
      justifyContent: 'center', background: 'var(--c-bg)', padding: 16,
    }}>
      <div style={{ width: '100%', maxWidth: 400 }}>
        {/* Brand header */}
        <div style={{ textAlign: 'center', marginBottom: 32 }}>
          <div style={{
            display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
            width: 56, height: 56, borderRadius: '50%',
            background: 'var(--c-red)', marginBottom: 14,
          }}>
            <span style={{ color: '#fff', fontWeight: 900, fontSize: 22 }}>V</span>
          </div>
          <h1 style={{ fontSize: 26, fontWeight: 800, color: 'var(--c-red)', letterSpacing: '-0.5px' }}>
            VIVA
          </h1>
          <p style={{ fontSize: 13, color: 'var(--c-text-secondary)', marginTop: 2 }}>
            Matrimony Administration
          </p>
        </div>

        {/* Card */}
        <div className="card" style={{ padding: '28px 28px 24px' }}>
          <h2 style={{ fontSize: 16, fontWeight: 700, marginBottom: 20 }}>Sign in to continue</h2>

          {error && (
            <div className="alert alert-error" role="alert" style={{ marginBottom: 16 }}>
              <span>⚠</span>
              <span>{error}</span>
            </div>
          )}

          <form onSubmit={handleSubmit} noValidate>
            <div style={{ marginBottom: 14 }}>
              <label className="field-label" htmlFor="email">Email address</label>
              <input
                id="email"
                type="email"
                className="input"
                value={email}
                onChange={e => setEmail(e.target.value)}
                placeholder="admin@viva.app"
                required
                autoComplete="email"
                autoFocus
                disabled={loading}
              />
            </div>

            <div style={{ marginBottom: 22 }}>
              <label className="field-label" htmlFor="password">Password</label>
              <input
                id="password"
                type="password"
                className="input"
                value={password}
                onChange={e => setPassword(e.target.value)}
                placeholder="••••••••"
                required
                autoComplete="current-password"
                disabled={loading}
              />
            </div>

            <button
              type="submit"
              className="btn btn-primary btn-lg"
              style={{ width: '100%' }}
              disabled={loading || !email || !password}
            >
              {loading ? 'Signing in…' : 'Sign In'}
            </button>
          </form>
        </div>

        <p style={{ textAlign: 'center', fontSize: 11, color: 'var(--c-text-tertiary)', marginTop: 20 }}>
          Viva Matrimony · Restricted access
        </p>
      </div>
    </div>
  );
}
