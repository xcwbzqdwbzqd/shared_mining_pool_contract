import type { FlowStep, UserSnapshot } from "@/lib/types";
import { FlowStepCard } from "./FlowStepCard";

function mergeUserOverrides(flowSteps: FlowStep[], userSnapshot?: UserSnapshot | null) {
  if (!userSnapshot) {
    return flowSteps;
  }

  return flowSteps.map((step) => {
    if (step.step === 11) {
      const availability = userSnapshot.actionAvailability.claimMyRewards;
      return {
        ...step,
        status: availability.available ? "Available Now" : step.status,
        reason: availability.reason,
      } satisfies FlowStep;
    }

    if (step.step === 14) {
      const availability = userSnapshot.actionAvailability.claimMyShare;
      return {
        ...step,
        status: availability.available ? "Available Now" : step.status,
        reason: availability.reason,
      } satisfies FlowStep;
    }

    return step;
  });
}

export function LifecycleFlowBoard({
  flowSteps,
  userSnapshot,
}: {
  flowSteps: FlowStep[];
  userSnapshot?: UserSnapshot | null;
}) {
  const mergedSteps = mergeUserOverrides(flowSteps, userSnapshot);

  return (
    <section className="panel flex flex-col gap-5 px-6 py-6 lg:px-8">
      <div className="flex flex-col gap-3 lg:flex-row lg:items-end lg:justify-between">
        <div>
          <p className="text-xs uppercase tracking-[0.3em] text-ink-soft">Depositor Lifecycle Flow</p>
          <h2 className="mt-2 text-2xl font-semibold text-ink sm:text-3xl">
            Follow the pool state machine in the same order the contract enforces it.
          </h2>
        </div>
        <p className="max-w-xl text-sm leading-6 text-ink-muted">
          Depositor actions stay highlighted when the connected address can execute them. Operator-only and
          permissionless transitions remain visible so the full custody model is always explicit.
        </p>
      </div>
      <div className="grid gap-4 xl:grid-cols-2 2xl:grid-cols-3">
        {mergedSteps.map((step) => (
          <FlowStepCard key={step.step} step={step} />
        ))}
      </div>
    </section>
  );
}
