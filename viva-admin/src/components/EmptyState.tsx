interface Props {
  icon?: string;
  title: string;
  subtitle?: string;
  action?: React.ReactNode;
}

export default function EmptyState({ icon = '📭', title, subtitle, action }: Props) {
  return (
    <div className="empty-state">
      <div style={{ fontSize: 36 }}>{icon}</div>
      <strong style={{ fontSize: 14, color: 'var(--c-text-secondary)' }}>{title}</strong>
      {subtitle && <p>{subtitle}</p>}
      {action}
    </div>
  );
}
