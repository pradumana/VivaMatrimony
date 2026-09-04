/** Format ISO date string → "14 Jan 2025" */
export function fmtDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString('en-IN', {
    day: '2-digit', month: 'short', year: 'numeric',
  });
}

/** Format ISO date string → "14 Jan 2025, 10:35 AM" */
export function fmtDateTime(iso: string | null | undefined): string {
  if (!iso) return '—';
  return new Date(iso).toLocaleString('en-IN', {
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  });
}

/** Relative time: "2 hours ago", "3 days ago" */
export function timeAgo(iso: string | null | undefined): string {
  if (!iso) return 'Never';
  const diff = Date.now() - new Date(iso).getTime();
  const m = Math.floor(diff / 60_000);
  if (m < 1) return 'Just now';
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  const d = Math.floor(h / 24);
  if (d < 7) return `${d}d ago`;
  return fmtDate(iso);
}

/** Capitalize first letter */
export function cap(s: string | null | undefined): string {
  if (!s) return '—';
  return s.charAt(0).toUpperCase() + s.slice(1).replace(/_/g, ' ');
}

/** Phone: show last 4 digits, mask rest */
export function maskPhone(phone: string | null | undefined): string {
  if (!phone) return '—';
  return phone.replace(/(\+?\d+?)(\d{4})$/, (_, prefix, last) =>
    prefix.replace(/\d/g, '•') + last,
  );
}
