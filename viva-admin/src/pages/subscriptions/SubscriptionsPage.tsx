import { useCallback, useEffect, useRef, useState } from 'react';
import { api } from '@/services/api';
import { useTitle } from '@/hooks/useTitle';
import type { Subscription, SubscriptionsResponse } from '@/types';
import { apiErrorMessage } from '@/app/AuthContext';
import { fmtDate, fmtDateTime, maskPhone } from '@/utils/format';
import { debounce } from '@/utils/debounce';
import Pagination from '@/components/Pagination';
import TableSkeleton from '@/components/TableSkeleton';
import ErrorAlert from '@/components/ErrorAlert';

const PAGE_SIZE = 20;

function isExpired(expires_at: string) {
  return new Date(expires_at) < new Date();
}

export default function SubscriptionsPage() {
  useTitle('Subscriptions');

  const [subs, setSubs]       = useState<Subscription[]>([]);
  const [total, setTotal]     = useState(0);
  const [page, setPage]       = useState(1);
  const [search, setSearch]   = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError]     = useState<string | null>(null);

  // Add payment form
  const [showForm, setShowForm]     = useState(false);
  const [formUserId, setFormUserId] = useState('');
  const [formAmount, setFormAmount] = useState('500');
  const [formPaidAt, setFormPaidAt] = useState('');
  const [formNotes, setFormNotes]   = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError]   = useState<string | null>(null);
  const [formSuccess, setFormSuccess] = useState<string | null>(null);

  const [csvLoading, setCsvLoading] = useState(false);

  const fetchSubs = useCallback(async (q: string, pg: number) => {
    setLoading(true);
    setError(null);
    try {
      const res = await api.getSubscriptions({
        search: q || undefined,
        page: pg,
        page_size: PAGE_SIZE,
      });
      const data = res.data as SubscriptionsResponse;
      setSubs(data.subscriptions);
      setTotal(data.total);
    } catch (err) {
      setError(apiErrorMessage(err));
    } finally {
      setLoading(false);
    }
  }, []);

  const debouncedFetch = useRef(
    debounce((q: string, pg: number) => fetchSubs(q, pg), 350),
  ).current;

  useEffect(() => {
    debouncedFetch(search, page);
  }, [search, page, debouncedFetch]);

  function handleSearch(val: string) {
    setSearch(val);
    setPage(1);
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setFormError(null);
    setFormSuccess(null);

    const amount = parseInt(formAmount, 10);
    if (!formUserId.trim()) { setFormError('User ID is required.'); return; }
    if (isNaN(amount) || amount < 300 || amount > 800) {
      setFormError('Amount must be between ₹300 and ₹800.');
      return;
    }

    setSubmitting(true);
    try {
      const res = await api.createSubscription({
        user_id: formUserId.trim(),
        amount,
        paid_at: formPaidAt || undefined,
        notes: formNotes.trim() || undefined,
      });
      const data = res.data as { expires_at: string };
      setFormSuccess(`Payment recorded. Valid until ${fmtDate(data.expires_at)}.`);
      setFormUserId(''); setFormAmount('500'); setFormPaidAt(''); setFormNotes('');
      fetchSubs(search, page);
    } catch (err) {
      setFormError(apiErrorMessage(err));
    } finally {
      setSubmitting(false);
    }
  }

  async function handleDownloadCSV() {
    setCsvLoading(true);
    try {
      const res = await api.downloadSubscriptionsCSV();
      const url = URL.createObjectURL(new Blob([res.data], { type: 'text/csv' }));
      const a = document.createElement('a');
      a.href = url;
      a.download = `subscriptions_${new Date().toISOString().slice(0, 10)}.csv`;
      a.click();
      URL.revokeObjectURL(url);
    } catch (err) {
      setError(apiErrorMessage(err));
    } finally {
      setCsvLoading(false);
    }
  }

  return (
    <>
      <div className="page-header">
        <div>
          <h1 className="page-title">Subscriptions</h1>
          <p className="page-subtitle">{total > 0 ? `${total.toLocaleString('en-IN')} records` : ''}</p>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <button
            className="btn btn-secondary btn-sm"
            onClick={handleDownloadCSV}
            disabled={csvLoading}
          >
            {csvLoading ? 'Downloading…' : '⬇ Download CSV'}
          </button>
          <button
            className="btn btn-primary btn-sm"
            onClick={() => { setShowForm(f => !f); setFormError(null); setFormSuccess(null); }}
          >
            {showForm ? 'Cancel' : '+ Record Payment'}
          </button>
        </div>
      </div>

      {/* Add payment form */}
      {showForm && (
        <div className="card" style={{ marginBottom: 20, padding: '20px 24px' }}>
          <h2 style={{ fontSize: 15, fontWeight: 700, marginBottom: 16 }}>Record Payment</h2>

          {formError && (
            <div className="alert alert-error" role="alert" style={{ marginBottom: 12 }}>
              <span>⚠</span><span>{formError}</span>
            </div>
          )}
          {formSuccess && (
            <div className="alert alert-success" role="alert" style={{ marginBottom: 12 }}>
              <span>✓</span><span>{formSuccess}</span>
            </div>
          )}

          <form onSubmit={handleSubmit}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px 16px' }}>
              <div>
                <label className="field-label" htmlFor="sub-user-id">User ID *</label>
                <input
                  id="sub-user-id"
                  className="input"
                  placeholder="Paste user UUID"
                  value={formUserId}
                  onChange={e => setFormUserId(e.target.value)}
                  required
                  disabled={submitting}
                />
              </div>
              <div>
                <label className="field-label" htmlFor="sub-amount">Amount (₹300–800) *</label>
                <input
                  id="sub-amount"
                  className="input"
                  type="number"
                  min={300}
                  max={800}
                  value={formAmount}
                  onChange={e => setFormAmount(e.target.value)}
                  required
                  disabled={submitting}
                />
              </div>
              <div>
                <label className="field-label" htmlFor="sub-paid-at">
                  Payment Date <span style={{ color: 'var(--c-text-tertiary)', fontWeight: 400 }}>(optional, defaults to today)</span>
                </label>
                <input
                  id="sub-paid-at"
                  className="input"
                  type="datetime-local"
                  value={formPaidAt}
                  onChange={e => setFormPaidAt(e.target.value)}
                  disabled={submitting}
                />
              </div>
              <div>
                <label className="field-label" htmlFor="sub-notes">Notes (optional)</label>
                <input
                  id="sub-notes"
                  className="input"
                  placeholder="e.g. Cash payment, UPI ref #123"
                  value={formNotes}
                  onChange={e => setFormNotes(e.target.value)}
                  disabled={submitting}
                />
              </div>
            </div>
            <div style={{ marginTop: 16 }}>
              <button
                type="submit"
                className="btn btn-primary"
                disabled={submitting}
              >
                {submitting ? 'Saving…' : 'Save Payment'}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Search */}
      <div className="filters-row">
        <input
          className="input"
          style={{ maxWidth: 280 }}
          type="search"
          placeholder="Search name or phone…"
          value={search}
          onChange={e => handleSearch(e.target.value)}
          aria-label="Search subscriptions"
        />
        {search && (
          <button
            className="btn btn-ghost btn-sm"
            onClick={() => { setSearch(''); setPage(1); }}
          >
            ✕ Clear
          </button>
        )}
      </div>

      <ErrorAlert message={error} onRetry={() => fetchSubs(search, page)} />

      <div className="card">
        <div className="table-wrap">
          {loading ? (
            <TableSkeleton rows={8} cols={7} />
          ) : (
            <table className="data-table">
              <thead>
                <tr>
                  <th>Member</th>
                  <th>Phone</th>
                  <th>Amount</th>
                  <th>Paid On</th>
                  <th>Expires</th>
                  <th>Status</th>
                  <th>Recorded By</th>
                  <th>Notes</th>
                </tr>
              </thead>
              <tbody>
                {subs.length === 0 ? (
                  <tr>
                    <td colSpan={8} style={{ textAlign: 'center', padding: '32px', color: 'var(--c-text-tertiary)' }}>
                      No records found
                    </td>
                  </tr>
                ) : subs.map(s => {
                  const expired = isExpired(s.expires_at);
                  return (
                    <tr key={s.id}>
                      <td style={{ fontWeight: 600 }}>
                        {s.full_name ?? <em style={{ color: 'var(--c-text-tertiary)' }}>No name</em>}
                      </td>
                      <td style={{ fontFamily: 'var(--font-mono)', fontSize: 12 }}>
                        {maskPhone(s.phone)}
                      </td>
                      <td style={{ fontWeight: 700, color: 'var(--c-text-primary)' }}>
                        ₹{s.amount}
                      </td>
                      <td style={{ color: 'var(--c-text-secondary)', fontSize: 12 }}>
                        {fmtDateTime(s.paid_at)}
                      </td>
                      <td style={{ color: 'var(--c-text-secondary)', fontSize: 12 }}>
                        {fmtDate(s.expires_at)}
                      </td>
                      <td>
                        <span style={{
                          display: 'inline-block',
                          padding: '2px 8px',
                          borderRadius: 12,
                          fontSize: 11,
                          fontWeight: 600,
                          background: expired ? 'var(--c-danger-bg, #fee2e2)' : 'var(--c-success-bg, #dcfce7)',
                          color: expired ? 'var(--c-danger, #dc2626)' : 'var(--c-success, #16a34a)',
                        }}>
                          {expired ? 'Expired' : 'Active'}
                        </span>
                      </td>
                      <td style={{ fontSize: 12, color: 'var(--c-text-secondary)' }}>
                        {s.recorded_by_name}
                      </td>
                      <td style={{ fontSize: 12, color: 'var(--c-text-secondary)', maxWidth: 180, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {s.notes ?? '—'}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </div>
      </div>

      <Pagination
        page={page}
        pageSize={PAGE_SIZE}
        total={total}
        onPageChange={setPage}
      />
    </>
  );
}
