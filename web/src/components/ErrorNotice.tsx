interface ErrorNoticeProps {
  message: string;
  onRetry: () => void;
  compact?: boolean;
}

export function ErrorNotice({ message, onRetry, compact }: ErrorNoticeProps) {
  return (
    <div
      role="alert"
      className={`rounded-xl border border-red-900/60 bg-red-950/30 ${compact ? "p-4" : "p-6"}`}
    >
      <p className={`text-red-300 ${compact ? "text-xs" : "text-sm"}`}>
        {message}
      </p>
      <button
        type="button"
        onClick={onRetry}
        className="mt-3 rounded-lg border border-zinc-700 bg-zinc-900 px-3 py-1.5 text-xs font-medium text-zinc-200 transition-colors hover:border-zinc-500 hover:bg-zinc-800"
      >
        Retry
      </button>
    </div>
  );
}
