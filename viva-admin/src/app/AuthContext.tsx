import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { useNavigate } from 'react-router-dom';
import { api, apiErrorMessage, setOn401Handler, tokenStore } from '@/services/api';
import type { AdminRole, AdminUser, LoginResponse } from '@/types';

interface AuthContextValue {
  admin: AdminUser | null;
  isLoading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  can: (permission: string) => boolean;
}

const AuthContext = createContext<AuthContextValue | null>(null);

// Simple RBAC — mirrors backend perms so UI hides unauthorised controls.
// Backend remains the real enforcement boundary.
const PERMS: Record<AdminRole, Set<string>> = {
  super_admin: new Set(['*']),
  admin: new Set(['verify', 'moderate', 'view_users', 'ban', 'suspend', 'audit']),
  moderator: new Set(['moderate', 'view_users', 'audit']),
  support: new Set(['view_users', 'audit']),
};

export function AuthProvider({ children }: { children: ReactNode }) {
  const navigate = useNavigate();
  const [admin, setAdmin] = useState<AdminUser | null>(null);
  const [isLoading, setIsLoading] = useState(true); // true until hydration checked

  // Hydrate from sessionStorage on mount
  useEffect(() => {
    const stored = sessionStorage.getItem('viva_admin_user');
    if (stored && tokenStore.get()) {
      try {
        setAdmin(JSON.parse(stored) as AdminUser);
      } catch {
        sessionStorage.removeItem('viva_admin_user');
      }
    }
    setIsLoading(false);
  }, []);

  const logout = useCallback(() => {
    tokenStore.clear();
    sessionStorage.removeItem('viva_admin_user');
    setAdmin(null);
    navigate('/login', { replace: true });
  }, [navigate]);

  // Wire the 401 handler once — logout is stable (useCallback)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => {
    setOn401Handler(logout);
  }, [logout]);

  const login = useCallback(async (email: string, password: string) => {
    const res = await api.login(email, password);
    const data = res.data as LoginResponse;
    tokenStore.set(data.access_token);
    const user: AdminUser = {
      admin_id: '', // backend doesn't return this in login; fine for UI
      email,
      full_name: data.full_name,
      role: data.role,
    };
    sessionStorage.setItem('viva_admin_user', JSON.stringify(user));
    setAdmin(user);
    navigate('/admin/dashboard', { replace: true });
  }, [navigate]);

  const can = useCallback(
    (permission: string): boolean => {
      if (!admin) return false;
      const set = PERMS[admin.role] ?? new Set();
      return set.has('*') || set.has(permission);
    },
    [admin],
  );

  const value = useMemo(
    () => ({ admin, isLoading, login, logout, can }),
    [admin, isLoading, login, logout, can],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider');
  return ctx;
}

// Standalone hook so consumers don't need to import apiErrorMessage
export { apiErrorMessage };
