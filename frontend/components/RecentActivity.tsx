import type { ActivityRecord } from "@/lib/types";

export function RecentActivity({ events }: { events: ActivityRecord[] }) {
  return (
    <section className="panel flex flex-col gap-5 px-6 py-6 lg:px-8">
      <div className="flex items-end justify-between gap-4">
        <div>
          <p className="text-xs uppercase tracking-[0.28em] text-ink-soft">Recent Activity</p>
          <h2 className="mt-2 text-2xl font-semibold text-ink">Recent chain-confirmed pool events</h2>
        </div>
        <span className="data-chip">{events.length} latest entries</span>
      </div>
      <div className="grid gap-4">
        {events.length === 0 ? (
          <div className="panel-muted px-4 py-4 text-sm text-ink-muted">
            No live events have been indexed for the fixed pool yet.
          </div>
        ) : (
          events.map((event) => (
            <article className="panel-muted grid gap-2 px-4 py-4 md:grid-cols-[1fr_auto]" key={event.id}>
              <div>
                <p className="text-sm font-semibold text-ink">{event.title}</p>
                <p className="mt-1 text-sm text-ink-muted">{event.summary}</p>
                <p className="mt-2 text-xs uppercase tracking-[0.18em] text-ink-soft">
                  {event.actor}
                  {event.epoch ? ` · Epoch ${event.epoch}` : ""}
                </p>
              </div>
              <div className="text-right text-xs text-ink-soft">
                <p>Block {event.blockNumber}</p>
                <p className="mt-1 break-all font-mono">{event.transactionHash.slice(0, 18)}...</p>
                <p className="mt-1">{new Date(event.timestamp).toLocaleString()}</p>
              </div>
            </article>
          ))
        )}
      </div>
    </section>
  );
}
