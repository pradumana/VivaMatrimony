import { useEffect, useState } from 'react';
import { api } from '@/services/api';
import { useTitle } from '@/hooks/useTitle';
import type { AuditLog, AuditLogsResponse } from '@/types';
import { apiErrorMessage } from '@/app/AuthContext';
import TableSkeleton from '@/components/TableSkeleton';
import ErrorAlert from '@/components/ErrorAlert';
import EmptyState from '@/components/EmptyState';
import { cap, fmtDateTime } from '@/utils/format';
import { debounce } from '@/utils/debounce';
import { useRef } from 'react';

export default function AuditLogsPage() {
  useTitle('Audit Logs');
  const [logs, setLogs]       = useState<AuditLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError]     = useState<string | null>(null);
  const [actionFilter, setActionFilter] = useState('');

  const fetchLogs = (action: string) => {
    setLoading(true);
    setError(null);
    api.getAuditLogs({ action: action || undefined, limit: 100 })
      .then(r => setLogs((r.data as AuditLogsResponse).logs))
      .catch(err => setError(apiErrorMessage(err)))
      .finally(() => setLoading(false));
  };

  const debouncedFetch = useRef(
    debounce((a: string) => fetchLogs(a), 400),
  ).current;

  useEffect(() => { fetchLogs(''); }, []);

  function handleFilter(val: string) {
    setActionFilter(val);
    debouncedFetch(val);
  }

  return (
    <>
      <div className="page-header">
        <div>
          <h1 className="page-title">Audit Logs</h1>
          <p className="page-subtitle">Administrative action history</p>
        </div>
      </div>

      <div className="filters-row">
        <input
          className="input"
          style={{ maxWidth: 260 }}
          placeholder="Filter by action…"
          value={actionFilter}
          onChange={e => handleFilter(e.target.value)}
          aria-label="Filter audit logs by action"
        />
        {actionFilter && (
          <button className="btn btn-ghost btn-sm" onClick={() => handleFilter('')}>✕ Clear</button>
        )}
      </div>

      <ErrorAlert message={error} onRetry={() => fetchLogs(actionFilter)} />

      <div className="card">
        <div className="table-wrap">
          {loading ? (
            <TableSkeleton rows={10} cols={5} />
          ) : logs.length === 0 ? (
            <EmptyState icon="📋" title="No audit logs found" />
          ) : (
            <table className="data-table">
              <thead>
                <tr>
                  <th>Timestamp</th>
                  <th>Actor</th>
                  <th>Action</th>
                  <th>Target</th>
                  <th>IP</th>
                </tr>
              </thead>
              <tbody>
                {logs.map(log => (
                  <tr key={log.id}>
                    <td style={{ fontSize: 12, whiteSpace: 'nowrap', color: 'var(--c-text-secondary)' }}>
                      {fmtDateTime(log.created_at)}
                    </td>
                    <td>
                      <span style={{ fontSize: 11 }}>
                        <span className="badge badge-verified">{cap(log.actor_type)}</span>
                      </span>
                      <div style={{ fontSize: 11, color: 'var(--c-text-tertiary)', marginTop: 2 }}>
                        {log.actor_id.slice(0, 8)}…
                      </div>
                    </td>
                    <td>
                      <code style={{
                        fontSize: 12, padding: '2px 6px',
                        background: 'var(--c-cream)', borderRadius: 4,
                        fontFamily: 'var(--font-mono)',
                      }}>
                        {log.action}
                      </code>
                    </td>
                    <td style={{ fontSize: 12, color: 'var(--c-text-secondary)' }}>
                      {log.target_type && (
                        <span>{cap(log.target_type)}</span>
                      )}
                      {log.target_id && (
                        <div style={{ fontSize: 11, color: 'var(--c-text-tertiary)' }}>
                          {log.target_id.slice(0, 8)}…
                        </div>
                      )}
                    </td>
                    <td style={{ fontSize: 11, color: 'var(--c-text-tertiary)', fontFamily: 'var(--font-mono)' }}>
                      {log.ip_address ?? '—'}
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
