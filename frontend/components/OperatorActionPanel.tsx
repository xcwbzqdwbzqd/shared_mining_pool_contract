"use client";

import { useState } from "react";
import { usePublicClient, useWriteContract } from "wagmi";
import { APP_CONFIG } from "@/config";
import { sharedMiningPoolV2Abi } from "@/lib/abi/sharedMiningPoolV2Abi";
import { parseEpochListInput, validateEpochList, validateMiningCalldata } from "@/lib/client/preflight";

export function OperatorActionPanel({ onConfirmed }: { onConfirmed: () => Promise<void> }) {
  const publicClient = usePublicClient({ chainId: APP_CONFIG.chainId });
  const { writeContractAsync, isPending } = useWriteContract();
  const [claimEpochs, setClaimEpochs] = useState("");
  const [bonusEpochs, setBonusEpochs] = useState("");
  const [calldata, setCalldata] = useState("");
  const [statusMessage, setStatusMessage] = useState("No operator transaction submitted yet.");

  const claimValidation = validateEpochList(claimEpochs);
  const bonusValidation = validateEpochList(bonusEpochs);
  const calldataValidation = validateMiningCalldata(calldata);

  async function executeWrite(functionName: string, args: unknown[] = []) {
    if (!publicClient) {
      return;
    }

    const hash = await writeContractAsync({
      address: APP_CONFIG.defaultPoolAddress,
      abi: sharedMiningPoolV2Abi,
      functionName,
      args,
      chainId: APP_CONFIG.chainId,
    });

    setStatusMessage(`${functionName} submitted: ${hash}`);
    await publicClient.waitForTransactionReceipt({ hash });
    await onConfirmed();
  }

  return (
    <section className="panel flex flex-col gap-5 px-6 py-6">
      <div>
        <p className="text-xs uppercase tracking-[0.28em] text-ink-soft">Operator Action Panel</p>
        <h2 className="mt-2 text-2xl font-semibold text-ink">Restricted to the fixed operator wallet</h2>
        <p className="mt-2 text-sm leading-6 text-ink-muted">
          This panel intentionally excludes coordinator auth, challenge solving, and receipt packaging. It only
          exposes the chain writes that the operator or keeper may need after off-chain work is complete.
        </p>
      </div>
      <div className="grid gap-4 xl:grid-cols-2">
        <article className="panel-muted flex flex-col gap-4 px-4 py-4">
          <p className="text-sm font-semibold text-ink">Checkpoint / Stake</p>
          <div className="flex flex-wrap gap-3">
            <button
              className="rounded-full bg-brand px-4 py-3 text-sm font-semibold text-surface-soft disabled:cursor-not-allowed disabled:opacity-45"
              onClick={() => void executeWrite("processEpochCheckpoint")}
              type="button"
            >
              {isPending ? "Submitting..." : "Process Epoch Checkpoint"}
            </button>
            <button
              className="rounded-full bg-brand px-4 py-3 text-sm font-semibold text-surface-soft disabled:cursor-not-allowed disabled:opacity-45"
              onClick={() => void executeWrite("stakeAvailablePrincipal")}
              type="button"
            >
              {isPending ? "Submitting..." : "Stake Available Principal"}
            </button>
          </div>
        </article>
        <article className="panel-muted flex flex-col gap-4 px-4 py-4">
          <p className="text-sm font-semibold text-ink">Submit Mining Receipt</p>
          <textarea
            className="min-h-32 rounded-2xl border border-line bg-surface px-4 py-3 text-xs text-ink"
            onChange={(event) => setCalldata(event.target.value)}
            placeholder="0xf9b5aac1..."
            value={calldata}
          />
          <p className={`text-xs ${calldataValidation.available ? "text-success" : "text-ink-soft"}`}>
            {calldataValidation.reason}
          </p>
          <button
            className="rounded-full bg-brand px-4 py-3 text-sm font-semibold text-surface-soft disabled:cursor-not-allowed disabled:opacity-45"
            disabled={!calldataValidation.available}
            onClick={() => void executeWrite("submitToMining", [calldata as `0x${string}`])}
            type="button"
          >
            {isPending ? "Submitting..." : "Submit To Mining"}
          </button>
        </article>
        <article className="panel-muted flex flex-col gap-4 px-4 py-4">
          <p className="text-sm font-semibold text-ink">Claim Regular Rewards</p>
          <input
            className="rounded-2xl border border-line bg-surface px-4 py-3 text-sm text-ink"
            onChange={(event) => setClaimEpochs(event.target.value)}
            placeholder="1,2,3"
            value={claimEpochs}
          />
          <p className={`text-xs ${claimValidation.available ? "text-success" : "text-ink-soft"}`}>
            {claimValidation.reason}
          </p>
          <button
            className="rounded-full bg-brand px-4 py-3 text-sm font-semibold text-surface-soft disabled:cursor-not-allowed disabled:opacity-45"
            disabled={!claimValidation.available}
            onClick={() => void executeWrite("triggerClaim", [parseEpochListInput(claimEpochs).map(BigInt)])}
            type="button"
          >
            {isPending ? "Submitting..." : "Trigger Claim"}
          </button>
        </article>
        <article className="panel-muted flex flex-col gap-4 px-4 py-4">
          <p className="text-sm font-semibold text-ink">Claim Bonus Rewards</p>
          <input
            className="rounded-2xl border border-line bg-surface px-4 py-3 text-sm text-ink"
            onChange={(event) => setBonusEpochs(event.target.value)}
            placeholder="1,2,3"
            value={bonusEpochs}
          />
          <p className={`text-xs ${bonusValidation.available ? "text-success" : "text-ink-soft"}`}>
            {bonusValidation.reason}
          </p>
          <button
            className="rounded-full bg-brand px-4 py-3 text-sm font-semibold text-surface-soft disabled:cursor-not-allowed disabled:opacity-45"
            disabled={!bonusValidation.available}
            onClick={() => void executeWrite("triggerBonusClaim", [parseEpochListInput(bonusEpochs).map(BigInt)])}
            type="button"
          >
            {isPending ? "Submitting..." : "Trigger Bonus Claim"}
          </button>
        </article>
      </div>
      <div className="panel-muted px-4 py-4 text-xs text-ink-soft">{statusMessage}</div>
    </section>
  );
}
