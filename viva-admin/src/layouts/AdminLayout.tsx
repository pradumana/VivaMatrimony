import { useState } from 'react';
import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { useAuth } from '@/app/AuthContext';

interface NavItem {
  to: string;
  label: string;
  icon: string;
  permission?: string;
  superAdminOnly?: boolean;
}

const NAV_ITEMS: NavItem[] = [
  { to: '/admin/dashboard',     label: 'Dashboard',     icon: '⊞' },
  { to: '/admin/users',         label: 'Users',         icon: '👥', permission: 'view_users' },
  { to: '/admin/verification',  label: 'Verification',  icon: '✓',  permission: 'verify' },
  { to: '/admin/references',    label: 'References',    icon: '🔗', permission: 'verify' },
  { to: '/admin/reports',       label: 'Reports',       icon: '🚩', permission: 'moderate' },
];

const SUPER_ITEMS: NavItem[] = [
  { to: '/admin/admins',      label: 'Admins',      icon: '🛡', superAdminOnly: true },
  { to: '/admin/audit-logs',  label: 'Audit Logs',  icon: '📋', superAdminOnly: true },
];

const BOTTOM_ITEMS: NavItem[] = [
  { to: '/admin/settings', label: 'Settings', icon: '⚙' },
];

export default function AdminLayout() {
  const { admin, logout, can } = useAuth();
  const navigate = useNavigate();
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const isSuperAdmin = admin?.role === 'super_admin';

  const sidebarCls = [
    'sidebar',
    collapsed ? 'collapsed' : '',
    mobileOpen ? 'mobile-open' : '',
  ].filter(Boolean).join(' ');

  const renderNav = (items: NavItem[]) =>
    items
      .filter(item => {
        if (item.superAdminOnly && !isSuperAdmin) return false;
        if (item.permission && !can(item.permission)) return false;
        return true;
      })
      .map(item => (
        <NavLink
          key={item.to}
          to={item.to}
          className={({ isActive }) => `nav-item${isActive ? ' active' : ''}`}
          onClick={() => setMobileOpen(false)}
          title={collapsed ? item.label : undefined}
        >
          <span style={{ fontSize: 16, flexShrink: 0 }}>{item.icon}</span>
          {!collapsed && <span>{item.label}</span>}
        </NavLink>
      ));

  return (
    <>
      {/* Mobile overlay */}
      {mobileOpen && (
        <div
          style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,.4)', zIndex: 99 }}
          onClick={() => setMobileOpen(false)}
        />
      )}

      {/* Sidebar */}
      <nav className={sidebarCls} aria-label="Main navigation">
        <div className="sidebar-logo">
          <span style={{ color: 'var(--c-red)', fontWeight: 900, fontSize: 20 }}>V</span>
          {!collapsed && (
            <>
              <span style={{ color: 'var(--c-red)', fontWeight: 800 }}>IVA</span>
              <span>Admin</span>
            </>
          )}
          <button
            className="btn btn-ghost btn-sm"
            style={{ marginLeft: 'auto', padding: '0 4px' }}
            onClick={() => setCollapsed(c => !c)}
            aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
          >
            {collapsed ? '›' : '‹'}
          </button>
        </div>

        <div className="sidebar-nav">
          {!collapsed && <div className="nav-section-label">Main</div>}
          {renderNav(NAV_ITEMS)}

          {isSuperAdmin && (
            <>
              {!collapsed && <div className="nav-section-label" style={{ marginTop: 8 }}>Super Admin</div>}
              {renderNav(SUPER_ITEMS)}
            </>
          )}
        </div>

        <div className="sidebar-footer">
          {renderNav(BOTTOM_ITEMS)}
          <button
            className="nav-item"
            style={{ width: '100%', border: 'none', textAlign: 'left', background: 'none' }}
            onClick={() => {
              logout();
            }}
            title={collapsed ? 'Log Out' : undefined}
          >
            <span style={{ fontSize: 16 }}>⏻</span>
            {!collapsed && <span>Log Out</span>}
          </button>
        </div>
      </nav>

      {/* Topbar */}
      <header className={`topbar${collapsed ? ' collapsed' : ''}`}>
        <button
          className="btn btn-ghost btn-sm"
          style={{ display: 'none' }}
          onClick={() => setMobileOpen(o => !o)}
          aria-label="Toggle menu"
          id="mobile-menu-btn"
        >
          ☰
        </button>

        <div className="topbar-right">
          {admin && (
            <div className="admin-chip">
              <span>{admin.full_name}</span>
              <span className="role-tag">{admin.role.replace('_', ' ')}</span>
            </div>
          )}
          <button
            className="btn btn-ghost btn-sm"
            onClick={logout}
            aria-label="Log out"
            title="Log out"
          >
            ⏻
          </button>
        </div>
      </header>

      {/* Main */}
      <main className={`main-content${collapsed ? ' collapsed' : ''}`}>
        <div className="content-inner">
          <Outlet />
        </div>
      </main>

      {/* Mobile toggle: show via CSS on small screens */}
      <style>{`
        @media (max-width: 768px) {
          #mobile-menu-btn { display: inline-flex !important; }
        }
      `}</style>
    </>
  );
}
