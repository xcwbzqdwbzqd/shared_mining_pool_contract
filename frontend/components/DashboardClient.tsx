"use client";

import { useQuery } from "@tanstack/react-query";
import { useAccount } from "wagmi";
import { LifecycleFlowBoard } from "@/components/LifecycleFlowBoard";
import { PoolHero } from "@/components/PoolHero";
import { RecentActivity } from "@/components/RecentActivity";
import { SafetyRules } from "@/components/SafetyRules";
import { ActionCenter } from "@/components/ActionCenter";
import { MyPosition } from "@/components/MyPosition";
import { APP_CONFIG } from "@/config";
import { useHeadAwareRefresh } from "@/lib/client/headPolling";
import type { DashboardSnapshot, UserSnapshot } from "@/lib/types";

async function fetchDashboard() {
  const response = await fetch("/api/dashboard", {
    cache: "no-store",
  });

  if (!response.ok) {
    throw new Error("Failed to fetch dashboard snapshot");
  }

  return (await response.json()) as DashboardSnapshot;
}

async function fetchUserSnapshot(address: string) {
  const response = await fetch(`/api/user/${address}`, {
    cache: "no-store",
  });

  if (!response.ok) {
    throw new Error("Failed to fetch user snapshot");
  }

  return (await response.json()) as UserSnapshot;
}

export function DashboardClient({ initialDashboard }: { initialDashboard: DashboardSnapshot }) {
  const { address } = useAccount();
  const dashboardQuery = useQuery({
    queryKey: ["dashboard"],
    queryFn: fetchDashboard,
    initialData: initialDashboard,
  });
  const userQuery = useQuery({
    queryKey: ["user-snapshot", address],
    queryFn: () => fetchUserSnapshot(address!),
    enabled: Boolean(address),
  });

  useHeadAwareRefresh(() => {
    void dashboardQuery.refetch();
    if (address) {
      void userQuery.refetch();
    }
  });

  const dashboard = dashboardQuery.data ?? initialDashboard;
  const userSnapshot = userQuery.data;

  return (
    <div className="flex flex-col gap-6 pt-6">
      <PoolHero snapshot={dashboard} />
      <div className="grid gap-6 xl:grid-cols-[1.2fr_0.8fr]">
        <LifecycleFlowBoard flowSteps={dashboard.flowSteps} userSnapshot={userSnapshot} />
        <div className="flex flex-col gap-6">
          <ActionCenter
            dashboard={dashboard}
            onConfirmed={async () => {
              await dashboardQuery.refetch();
              if (address) {
                await userQuery.refetch();
              }
            }}
            userSnapshot={userSnapshot}
          />
          <MyPosition userSnapshot={userSnapshot} />
        </div>
      </div>
      <div className="grid gap-6 xl:grid-cols-[1.15fr_0.85fr]">
        <RecentActivity events={dashboard.recentActivity} />
        <div className="flex flex-col gap-6">
          <SafetyRules />
          <section className="panel flex flex-col gap-3 px-6 py-6">
            <p className="text-xs uppercase tracking-[0.28em] text-ink-soft">Read-only mode</p>
            <h2 className="text-2xl font-semibold text-ink">No wallet is required to audit the live pool.</h2>
            <p className="text-sm leading-6 text-ink-muted">
              Wallet connection only unlocks address-specific overlays and transaction buttons. The entire pool
              state remains visible even in read-only mode because the application is pinned to the canonical pool
              instance.
            </p>
            <a
              className="mt-1 inline-flex w-fit items-center rounded-full bg-brand px-4 py-3 text-sm font-semibold text-surface-soft transition-opacity duration-200 hover:opacity-90"
              href="/history"
            >
              Open Full History
            </a>
            <p className="text-xs text-ink-soft">
              Latest block: {dashboard.blockNumber} · Pool: {APP_CONFIG.defaultPoolAddress}
            </p>
          </section>
        </div>
      </div>
    </div>
  );
}
