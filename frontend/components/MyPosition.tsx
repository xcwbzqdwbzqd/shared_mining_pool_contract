import type { UserSnapshot } from "@/lib/types";

const fields: Array<{
  key: keyof Pick<
    UserSnapshot,
    | "walletBalance"
    | "allowance"
    | "principal"
    | "withdrawnPrincipal"
    | "activeShares"
    | "pendingSharesNextEpoch"
    | "claimableRewards"
  >;
  label: string;
}> = [
  { key: "walletBalance", label: "Wallet BOTCOIN" },
  { key: "allowance", label: "Pool Allowance" },
  { key: "principal", label: "Principal Still In Pool" },
  { key: "withdrawnPrincipal", label: "Withdrawn Principal" },
  { key: "activeShares", label: "Current Active Shares" },
  { key: "pendingSharesNextEpoch", label: "Queued Shares Next Epoch" },
  { key: "claimableRewards", label: "Claimable Rewards" },
];

export function MyPosition({ userSnapshot }: { userSnapshot?: UserSnapshot | null }) {
  return (
    <section className="panel flex flex-col gap-5 px-6 py-6 lg:px-8">
      <div className="flex flex-col gap-2">
        <p className="text-xs uppercase tracking-[0.28em] text-ink-soft">My Position</p>
        <h2 className="text-2xl font-semibold text-ink">Personal principal, shares, and reward state</h2>
      </div>
      {!userSnapshot ? (
        <div className="panel-muted px-4 py-5 text-sm leading-6 text-ink-muted">
          Connect a Base wallet to overlay address-specific principal, share, allowance, and reward data on top
          of the public pool state.
        </div>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
          {fields.map((field) => (
            <article className="panel-muted flex flex-col gap-2 px-4 py-4" key={field.key}>
              <span className="text-xs uppercase tracking-[0.18em] text-ink-soft">{field.label}</span>
              <span className="text-xl font-semibold text-ink">{userSnapshot[field.key]}</span>
            </article>
          ))}
        </div>
      )}
    </section>
  );
}
