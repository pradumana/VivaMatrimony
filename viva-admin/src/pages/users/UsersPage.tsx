import { useCallback, useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '@/services/api';
import { useTitle } from '@/hooks/useTitle';
import type { UserSummary, UsersResponse } from '@/types';
import { apiErrorMessage } from '@/app/AuthContext';
import StatusBadge from '@/components/StatusBadge';
import Pagination from '@/components/Pagination';
import TableSkeleton from '@/components/TableSkeleton';
import ErrorAlert from '@/components/ErrorAlert';
import { fmtDate, maskPhone } from '@/utils/format';
import { debounce } from '@/utils/debounce';

const PAGE_SIZE = 20;

export default function UsersPage() {
  useTitle('Users');
  const [users, setUsers]         = useState<UserSummary[]>([]);
  const [total, setTotal]         = useState(0);
  const [page, setPage]           = useState(1);
  const [search, setSearch]       = useState('');
  const [acctStatus, setAcct]     = useState('');
  const [vfyStatus, setVfy]       = useState('');
  const [loading, setLoading]     = useState(true);
  const [error, setError]         = useState<string | null>(null);

  const fetchUsers = useCallback(async (q: string, acct: string, vfy: string, pg: number) => {
    setLoading(true);
    setError(null);
    try {
      const res = await api.getUsers({
        search: q || undefined,
        account_status: acct || undefined,
        verification_status: vfy || undefined,
        page: pg,
        page_size: PAGE_SIZE,
      });
      const data = res.data as UsersResponse;
      setUsers(data.users);
      setTotal(data.total);
    } catch (err) {
      setError(apiErrorMessage(err));
    } finally {
      setLoading(false);
    }
  }, []);

  // Debounced search
  const debouncedFetch = useRef(
    debounce((q: string, acct: string, vfy: string, pg: number) => {
      fetchUsers(q, acct, vfy, pg);
    }, 350),
  ).current;

  useEffect(() => {
    debouncedFetch(search, acctStatus, vfyStatus, page);
  }, [search, acctStatus, vfyStatus, page, debouncedFetch]);

  function handleSearch(val: string) {
    setSearch(val);
    setPage(1);
  }

  return (
    <>
      <div className="page-header">
        <div>
          <h1 className="page-title">Users</h1>
          <p className="page-subtitle">{total > 0 ? `${total.toLocaleString('en-IN')} total` : ''}</p>
        </div>
      </div>

      {/* Filters */}
      <div className="filters-row">
        <input
          className="input"
          style={{ maxWidth: 260 }}
          type="search"
          placeholder="Search name, phone, member ID…"
          value={search}
          onChange={e => handleSearch(e.target.value)}
          aria-label="Search users"
        />
        <select
          className="input"
          style={{ width: 150 }}
          value={acctStatus}
          onChange={e => { setAcct(e.target.value); setPage(1); }}
          aria-label="Account status filter"
        >
          <option value="">All Status</option>
          <option value="active">Active</option>
          <option value="pending_verification">Pending</option>
          <option value="suspended">Suspended</option>
          <option value="banned">Banned</option>
          <option value="deleted">Deleted</option>
        </select>
        <select
          className="input"
          style={{ width: 170 }}
          value={vfyStatus}
          onChange={e => { setVfy(e.target.value); setPage(1); }}
          aria-label="Verification status filter"
        >
          <option value="">All Verification</option>
          <option value="unverified">Unverified</option>
          <option value="pending">Pending</option>
          <option value="verified">Verified</option>
          <option value="rejected">Rejected</option>
        </select>
        {(search || acctStatus || vfyStatus) && (
          <button
            className="btn btn-ghost btn-sm"
            onClick={() => { setSearch(''); setAcct(''); setVfy(''); setPage(1); }}
          >
            ✕ Clear
          </button>
        )}
      </div>

      <ErrorAlert message={error} onRetry={() => fetchUsers(search, acctStatus, vfyStatus, page)} />

      <div className="card">
        <div className="table-wrap">
          {loading ? (
            <TableSkeleton rows={8} cols={6} />
          ) : (
            <table className="data-table">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Phone</th>
                  <th>Account</th>
                  <th>Verification</th>
                  <th>Complete %</th>
                  <th>Joined</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {users.length === 0 ? (
                  <tr>
                    <td colSpan={7} style={{ textAlign: 'center', padding: '32px', color: 'var(--c-text-tertiary)' }}>
                      No users found
                    </td>
                  </tr>
                ) : users.map(u => (
                  <tr key={u.user_id}>
                    <td>
                      <Link to={`/admin/users/${u.user_id}`} style={{ fontWeight: 600, color: 'var(--c-text-primary)' }}>
                        {u.full_name ?? <em style={{ color: 'var(--c-text-tertiary)' }}>No name</em>}
                      </Link>
                    </td>
                    <td style={{ fontFamily: 'var(--font-mono)', fontSize: 12 }}>{maskPhone(u.phone)}</td>
                    <td><StatusBadge status={u.account_status} /></td>
                    <td><StatusBadge status={u.verification_status} /></td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
                        <div style={{
                          flex: 1, height: 5, background: 'var(--c-border)',
                          borderRadius: 3, maxWidth: 60, overflow: 'hidden',
                        }}>
                          <div style={{
                            height: '100%', borderRadius: 3,
                            width: `${u.completion_percentage ?? 0}%`,
                            background: (u.completion_percentage ?? 0) >= 80
                              ? 'var(--c-success)' : 'var(--c-gold)',
                          }} />
                        </div>
                        <span style={{ fontSize: 11, color: 'var(--c-text-secondary)' }}>
                          {u.completion_percentage ?? 0}%
                        </span>
                      </div>
                    </td>
                    <td style={{ color: 'var(--c-text-secondary)', fontSize: 12 }}>{fmtDate(u.created_at)}</td>
                    <td>
                      <Link to={`/admin/users/${u.user_id}`} className="btn btn-sm btn-secondary">
                        View
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        {!loading && (
          <div style={{ padding: '10px 16px' }}>
            <Pagination page={page} pageSize={PAGE_SIZE} total={total} onPage={setPage} />
          </div>
        )}
      </div>
    </>
  );
}
