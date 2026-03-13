"use client";

import { useDeferredValue, useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { HistoryFilters } from "@/components/HistoryFilters";
import { HistoryTimeline } from "@/components/HistoryTimeline";
import { useHeadAwareRefresh } from "@/lib/client/headPolling";
import type { HistorySnapshot } from "@/lib/types";

async function fetchHistory() {
  const response = await fetch("/api/history?limit=120", {
    cache: "no-store",
  });

  if (!response.ok) {
    throw new Error("Failed to fetch history snapshot");
  }

  return (await response.json()) as HistorySnapshot;
}

export function HistoryClient({ initialHistory }: { initialHistory: HistorySnapshot }) {
  const [query, setQuery] = useState("");
  const deferredQuery = useDeferredValue(query);
  const historyQuery = useQuery({
    queryKey: ["history"],
    queryFn: fetchHistory,
    initialData: initialHistory,
  });

  useHeadAwareRefresh(() => {
    void historyQuery.refetch();
  });

  const filteredEvents = useMemo(() => {
    const value = deferredQuery.trim().toLowerCase();

    if (!value) {
      return historyQuery.data.events;
    }

    return historyQuery.data.events.filter((event) =>
      [event.title, event.summary, event.actor, event.epoch ?? "", event.transactionHash]
        .join(" ")
        .toLowerCase()
        .includes(value),
    );
  }, [deferredQuery, historyQuery.data.events]);

  return (
    <div className="flex flex-col gap-6 pt-6">
      <section className="panel flex flex-col gap-4 px-6 py-6">
        <p className="text-xs uppercase tracking-[0.28em] text-ink-soft">Full History</p>
        <h2 className="text-3xl font-semibold text-ink">Chain-confirmed lifecycle timeline for the canonical pool</h2>
        <p className="max-w-3xl text-sm leading-6 text-ink-muted">
          This page replays pool events from the live deployment block forward and keeps the latest block-aware
          tail in sync with the dashboard.
        </p>
      </section>
      <HistoryFilters onQueryChange={setQuery} query={query} />
      <HistoryTimeline events={filteredEvents} />
    </div>
  );
}
