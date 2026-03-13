const rules = [
  "Deposits activate on the next epoch rather than the current block.",
  "Rewards and principal are separate claim paths with separate preconditions.",
  "Unstake is permissionless only at or after the configured epoch boundary.",
  "Cooldown withdraw is permissionless only after Mining V2 marks the pool as withdrawable.",
  "The frontend is locked to one live pool instance and one live ABI to avoid selector drift.",
];

export function SafetyRules() {
  return (
    <section className="panel flex flex-col gap-5 px-6 py-6 lg:px-8">
      <div>
        <p className="text-xs uppercase tracking-[0.28em] text-ink-soft">Safety Rules</p>
        <h2 className="mt-2 text-2xl font-semibold text-ink">Contract constraints surfaced as product rules</h2>
      </div>
      <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
        {rules.map((rule) => (
          <article className="panel-muted px-4 py-4 text-sm leading-6 text-ink-muted" key={rule}>
            {rule}
          </article>
        ))}
      </div>
    </section>
  );
}
