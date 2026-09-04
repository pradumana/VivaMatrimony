import { useEffect, useRef, useState } from 'react';

interface Props {
  title: string;
  message: string;
  confirmLabel?: string;
  variant?: 'danger' | 'warning';
  /** When truthy: show a required textarea for a reason */
  requireReason?: boolean;
  reasonPlaceholder?: string;
  isLoading?: boolean;
  onConfirm: (reason?: string) => void;
  onCancel: () => void;
}

export default function ConfirmDialog({
  title,
  message,
  confirmLabel = 'Confirm',
  variant = 'danger',
  requireReason = false,
  reasonPlaceholder = 'Enter reason…',
  isLoading = false,
  onConfirm,
  onCancel,
}: Props) {
  const [reason, setReason] = useState('');
  const firstRef = useRef<HTMLButtonElement>(null);

  // Focus Cancel on open (safer default for destructive dialogs)
  useEffect(() => { firstRef.current?.focus(); }, []);

  // Close on Escape
  useEffect(() => {
    const fn = (e: KeyboardEvent) => { if (e.key === 'Escape') onCancel(); };
    window.addEventListener('keydown', fn);
    return () => window.removeEventListener('keydown', fn);
  }, [onCancel]);

  const canSubmit = !requireReason || reason.trim().length > 0;
  const btnCls = variant === 'danger' ? 'btn btn-danger' : 'btn btn-primary';

  return (
    <div className="modal-backdrop" role="dialog" aria-modal="true" aria-labelledby="dlg-title">
      <div className="modal">
        <div className="modal-header">
          <span className="modal-title" id="dlg-title">{title}</span>
        </div>
        <div className="modal-body">
          <p style={{ fontSize: 13, color: 'var(--c-text-secondary)', lineHeight: 1.6 }}>{message}</p>
          {requireReason && (
            <div style={{ marginTop: 14 }}>
              <label className="field-label" htmlFor="dlg-reason">Reason *</label>
              <textarea
                id="dlg-reason"
                className="input"
                rows={3}
                placeholder={reasonPlaceholder}
                value={reason}
                onChange={e => setReason(e.target.value)}
                style={{ resize: 'vertical' }}
              />
            </div>
          )}
        </div>
        <div className="modal-footer">
          <button
            ref={firstRef}
            className="btn btn-secondary"
            onClick={onCancel}
            disabled={isLoading}
          >
            Cancel
          </button>
          <button
            className={btnCls}
            onClick={() => onConfirm(requireReason ? reason : undefined)}
            disabled={isLoading || !canSubmit}
          >
            {isLoading ? 'Working…' : confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
