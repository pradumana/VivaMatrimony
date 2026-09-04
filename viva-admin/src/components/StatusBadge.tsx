import type { AccountStatus, CertStatus, ReferenceStatus, ReportStatus, VerificationStatus } from '@/types';

type BadgeStatus =
  | AccountStatus
  | VerificationStatus
  | CertStatus
  | ReferenceStatus
  | ReportStatus
  | string;

const LABEL: Record<string, string> = {
  active:               '✓ Active',
  pending_verification: '⏳ Pending',
  suspended:            '⚠ Suspended',
  banned:               '✕ Banned',
  deleted:              '✕ Deleted',
  unverified:           '— Unverified',
  verified:             '✓ Verified',
  pending:              '⏳ Pending',
  rejected:             '✕ Rejected',
  approved:             '✓ Approved',
  confirmed:            '✓ Confirmed',
  revoked:              '✕ Revoked',
  open:                 '● Open',
  under_review:         '⏳ Reviewing',
  resolved:             '✓ Resolved',
  dismissed:            '— Dismissed',
};

const CLS: Record<string, string> = {
  active: 'badge-active', pending_verification: 'badge-pending',
  suspended: 'badge-suspended', banned: 'badge-banned', deleted: 'badge-deleted',
  unverified: 'badge-unverified', verified: 'badge-verified',
  pending: 'badge-pending', rejected: 'badge-rejected', approved: 'badge-active',
  confirmed: 'badge-confirmed', revoked: 'badge-revoked',
  open: 'badge-open', under_review: 'badge-pending',
  resolved: 'badge-resolved', dismissed: 'badge-dismissed',
};

export default function StatusBadge({ status }: { status: BadgeStatus }) {
  const label = LABEL[status] ?? status;
  const cls = CLS[status] ?? 'badge-unverified';
  return <span className={`badge ${cls}`}>{label}</span>;
}
