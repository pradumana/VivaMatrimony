interface Props {
  page: number;
  pageSize: number;
  total: number;
  onPage: (p: number) => void;
}

export default function Pagination({ page, pageSize, total, onPage }: Props) {
  const pages = Math.ceil(total / pageSize);
  if (pages <= 1) return null;

  const from = (page - 1) * pageSize + 1;
  const to   = Math.min(page * pageSize, total);

  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 14, flexWrap: 'wrap', gap: 8 }}>
      <span style={{ fontSize: 12, color: 'var(--c-text-tertiary)' }}>
        {from}–{to} of {total}
      </span>
      <div className="pagination">
        <button
          className="btn btn-ghost btn-sm"
          onClick={() => onPage(page - 1)}
          disabled={page <= 1}
          aria-label="Previous page"
        >‹</button>

        {Array.from({ length: Math.min(pages, 7) }, (_, i) => {
          // Always show first, last, and pages around current
          let p: number;
          if (pages <= 7) {
            p = i + 1;
          } else if (i === 0) {
            p = 1;
          } else if (i === 6) {
            p = pages;
          } else if (page <= 4) {
            p = i + 1;
          } else if (page >= pages - 3) {
            p = pages - 6 + i;
          } else {
            p = page - 3 + i;
          }

          return p === page
            ? <span key={p} className="page-active">{p}</span>
            : <button key={p} className="btn btn-ghost btn-sm" onClick={() => onPage(p)}>{p}</button>;
        })}

        <button
          className="btn btn-ghost btn-sm"
          onClick={() => onPage(page + 1)}
          disabled={page >= pages}
          aria-label="Next page"
        >›</button>
      </div>
    </div>
  );
}
