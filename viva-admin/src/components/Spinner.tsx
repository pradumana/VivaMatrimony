export default function Spinner({ size = 20 }: { size?: number }) {
  return (
    <svg
      width={size} height={size} viewBox="0 0 24 24"
      fill="none" stroke="currentColor" strokeWidth={2.5}
      strokeLinecap="round"
      style={{ animation: 'spin 0.7s linear infinite', display: 'block' }}
      aria-hidden="true"
    >
      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
      <circle cx="12" cy="12" r="10" strokeOpacity={0.25} />
      <path d="M22 12a10 10 0 0 0-10-10" />
    </svg>
  );
}
