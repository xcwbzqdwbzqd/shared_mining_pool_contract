import { APP_CONFIG } from "@/config";
import type { DashboardSnapshot } from "@/lib/types";

const metricMap = [
  {
    label: "Phase",
    key: "phase",
  },
  {
    label: "Current Epoch",
    key: "currentEpoch",
  },
  {
    label: "Staked BOTCOIN",
    key: "stakedAmount",
  },
  {
    label: "Principal Liability",
    key: "totalPrincipalLiability",
  },
  {
    label: "Reward Reserve",
    key: "rewardReserve",
  },
  {
    label: "Pool BOT Balance",
    key: "poolTokenBalance",
  },
] as const;

export function PoolHero({ snapshot }: { snapshot: DashboardSnapshot }) {
  return (
    <section className="panel flex flex-col gap-6 px-6 py-6 lg:px-8">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
        <div className="max-w-3xl">
          <p className="text-xs uppercase tracking-[0.32em] text-ink-soft">Live Canonical Pool</p>
          <h2 className="mt-2 text-3xl font-semibold text-ink sm:text-4xl">
            Read the pool first, then act with chain-confirmed context.
          </h2>
          <p className="mt-3 max-w-2xl text-sm leading-6 text-ink-muted sm:text-base">
            This interface is bound to the latest Base mainnet pool instance only. It explains the live state,
            the reward cycle, the withdrawal path, and what the connected address can safely do right now.
          </p>
        </div>
        <div className="panel-muted flex flex-col gap-2 px-4 py-4 text-sm text-ink-muted">
          <span>Pool Address</span>
          <span className="font-mono text-xs text-ink sm:text-sm">{APP_CONFIG.defaultPoolAddress}</span>
          <span>Operator</span>
          <span className="font-mono text-xs text-ink sm:text-sm">{snapshot.operator}</span>
        </div>
      </div>
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        {metricMap.map((metric) => (
          <article className="panel-muted flex flex-col gap-2 px-4 py-4" key={metric.key}>
            <span className="text-xs uppercase tracking-[0.22em] text-ink-soft">{metric.label}</span>
            <span className="text-2xl font-semibold text-ink">
              {snapshot[metric.key] as string}
            </span>
          </article>
        ))}
      </div>
    </section>
  );
}
