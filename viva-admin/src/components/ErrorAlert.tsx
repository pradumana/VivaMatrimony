interface Props {
  message: string | null;
  onRetry?: () => void;
}

export default function ErrorAlert({ message, onRetry }: Props) {
  if (!message) return null;
  return (
    <div className="alert alert-error" role="alert">
      <span>⚠</span>
      <span style={{ flex: 1 }}>{message}</span>
      {onRetry && (
        <button className="btn btn-sm btn-secondary" onClick={onRetry} style={{ marginLeft: 8 }}>
          Retry
        </button>
      )}
    </div>
  );
}
