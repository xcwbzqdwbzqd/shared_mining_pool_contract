"use client";

type HistoryFiltersProps = {
  query: string;
  onQueryChange: (value: string) => void;
};

export function HistoryFilters({ query, onQueryChange }: HistoryFiltersProps) {
  return (
    <div className="panel-muted flex flex-col gap-3 px-4 py-4 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <p className="text-xs uppercase tracking-[0.18em] text-ink-soft">History Filters</p>
        <p className="mt-1 text-sm text-ink-muted">Filter by actor, title, transaction hash, or epoch number.</p>
      </div>
      <input
        className="w-full rounded-2xl border border-line bg-surface px-4 py-3 text-sm text-ink sm:max-w-sm"
        onChange={(event) => onQueryChange(event.target.value)}
        placeholder="Search recent pool history..."
        value={query}
      />
    </div>
  );
}
