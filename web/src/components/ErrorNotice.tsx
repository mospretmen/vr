interface ErrorNoticeProps {
  message: string;
  onRetry: () => void;
  compact?: boolean;
}

export function ErrorNotice({ message, onRetry, compact }: ErrorNoticeProps) {
  return (
    <div
      role="alert"
      className={`rounded-2xl border border-red-500/20 bg-red-950/25 ${compact ? "p-4" : "p-6"}`}
    >
      <p className={`text-red-300/90 ${compact ? "text-xs" : "text-sm"}`}>
        {message}
      </p>
      <button
        type="button"
        onClick={onRetry}
        className="mt-3 rounded-lg border border-white/10 bg-white/5 px-3 py-1.5 text-xs font-medium text-ink transition-colors hover:border-white/25 hover:bg-white/10"
      >
        Retry
      </button>
    </div>
  );
}
