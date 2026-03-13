"use client";

import { useQuery } from "@tanstack/react-query";
import { useAccount } from "wagmi";
import { APP_CONFIG } from "@/config";
import { OperatorActionPanel } from "@/components/OperatorActionPanel";
import { PoolHero } from "@/components/PoolHero";
import { RecentActivity } from "@/components/RecentActivity";
import { useHeadAwareRefresh } from "@/lib/client/headPolling";
import type { DashboardSnapshot } from "@/lib/types";

async function fetchDashboard() {
  const response = await fetch("/api/dashboard", {
    cache: "no-store",
  });

  if (!response.ok) {
    throw new Error("Failed to fetch dashboard snapshot");
  }

  return (await response.json()) as DashboardSnapshot;
}

export function OperatorGate({ initialDashboard }: { initialDashboard: DashboardSnapshot }) {
  const { address } = useAccount();
  const dashboardQuery = useQuery({
    queryKey: ["operator-dashboard"],
    queryFn: fetchDashboard,
    initialData: initialDashboard,
  });

  useHeadAwareRefresh(() => {
    void dashboardQuery.refetch();
  });

  if (!address || address.toLowerCase() !== APP_CONFIG.operatorAddress.toLowerCase()) {
    return (
      <div className="flex flex-col gap-6 pt-6">
        <section className="panel px-6 py-6">
          <p className="text-xs uppercase tracking-[0.28em] text-ink-soft">Operator Console</p>
          <h2 className="mt-2 text-3xl font-semibold text-ink">Access denied for the current wallet.</h2>
          <p className="mt-3 max-w-2xl text-sm leading-6 text-ink-muted">
            This route is intentionally hidden from non-operator addresses. Connect the fixed operator wallet
            `{APP_CONFIG.operatorAddress}` on Base mainnet to unlock chain write controls.
          </p>
        </section>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-6 pt-6">
      <PoolHero snapshot={dashboardQuery.data} />
      <OperatorActionPanel
        onConfirmed={async () => {
          await dashboardQuery.refetch();
        }}
      />
      <RecentActivity events={dashboardQuery.data.recentActivity} />
    </div>
  );
}
