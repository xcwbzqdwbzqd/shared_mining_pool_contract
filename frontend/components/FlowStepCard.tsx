import type { FlowStep } from "@/lib/types";

const statusClasses: Record<FlowStep["status"], string> = {
  Done: "border-success/40 bg-success/10 text-success",
  "Available Now": "border-brand/40 bg-brand-soft text-brand",
  "Waiting On Other Actor": "border-accent/40 bg-accent/10 text-accent",
  "Blocked By Protocol Condition": "border-line bg-surface-soft text-ink-muted",
};

export function FlowStepCard({ step }: { step: FlowStep }) {
  return (
    <article className="panel-muted flex h-full flex-col gap-4 px-4 py-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-xs uppercase tracking-[0.24em] text-ink-soft">Step {step.step}</p>
          <h3 className="mt-2 text-lg font-semibold text-ink">{step.title}</h3>
        </div>
        <span className={`rounded-full border px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.18em] ${statusClasses[step.status]}`}>
          {step.status}
        </span>
      </div>
      <dl className="grid gap-3 text-sm">
        <div>
          <dt className="text-xs uppercase tracking-[0.18em] text-ink-soft">Actor</dt>
          <dd className="mt-1 text-ink">{step.actor}</dd>
        </div>
        <div>
          <dt className="text-xs uppercase tracking-[0.18em] text-ink-soft">Contract Method</dt>
          <dd className="mt-1 break-all font-mono text-xs text-ink">{step.method}</dd>
        </div>
        <div>
          <dt className="text-xs uppercase tracking-[0.18em] text-ink-soft">On-chain Effect</dt>
          <dd className="mt-1 text-ink-muted">{step.onChainEffect}</dd>
        </div>
        <div>
          <dt className="text-xs uppercase tracking-[0.18em] text-ink-soft">Why blocked or ready</dt>
          <dd className="mt-1 text-ink-muted">{step.reason}</dd>
        </div>
        <div>
          <dt className="text-xs uppercase tracking-[0.18em] text-ink-soft">Next actor</dt>
          <dd className="mt-1 text-ink">{step.nextActor}</dd>
        </div>
      </dl>
    </article>
  );
}
