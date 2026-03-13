import type { ActivityRecord } from "@/lib/types";

export function HistoryTimeline({ events }: { events: ActivityRecord[] }) {
  return (
    <div className="grid gap-4">
      {events.map((event) => (
        <article className="panel-muted px-4 py-4" key={event.id}>
          <div className="flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
            <div>
              <p className="text-sm font-semibold text-ink">{event.title}</p>
              <p className="mt-1 text-sm text-ink-muted">{event.summary}</p>
              <p className="mt-2 text-xs uppercase tracking-[0.18em] text-ink-soft">
                {event.actor}
                {event.epoch ? ` · Epoch ${event.epoch}` : ""}
              </p>
            </div>
            <div className="text-left text-xs text-ink-soft md:text-right">
              <p>{new Date(event.timestamp).toLocaleString()}</p>
              <p className="mt-1">Block {event.blockNumber}</p>
              <p className="mt-1 break-all font-mono">{event.transactionHash}</p>
            </div>
          </div>
        </article>
      ))}
    </div>
  );
}
