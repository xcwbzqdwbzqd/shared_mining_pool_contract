"use client";

import { useState } from "react";
import { parseUnits } from "viem";
import { useAccount, usePublicClient, useWriteContract } from "wagmi";
import { APP_CONFIG } from "@/config";
import { erc20Abi } from "@/lib/abi/erc20Abi";
import { sharedMiningPoolV2Abi } from "@/lib/abi/sharedMiningPoolV2Abi";
import { parseEpochListInput, validateEpochList, validatePositiveTokenAmount } from "@/lib/client/preflight";
import type { DashboardSnapshot, UserSnapshot } from "@/lib/types";

type ActionCenterProps = {
  dashboard: DashboardSnapshot;
  userSnapshot?: UserSnapshot | null;
  onConfirmed: () => Promise<void>;
};

function statusLine(available: boolean, reason: string) {
  return (
    <p className={`text-xs ${available ? "text-success" : "text-ink-soft"}`}>
      {reason}
    </p>
  );
}

export function ActionCenter({ dashboard, userSnapshot, onConfirmed }: ActionCenterProps) {
  const { address, chainId, isConnected } = useAccount();
  const publicClient = usePublicClient({ chainId: APP_CONFIG.chainId });
  const { writeContractAsync, isPending } = useWriteContract();
  const [depositAmount, setDepositAmount] = useState("");
  const [claimEpochs, setClaimEpochs] = useState("");
  const [principalAmount, setPrincipalAmount] = useState("");
  const [statusMessage, setStatusMessage] = useState("No transaction submitted yet.");

  const depositValidation = validatePositiveTokenAmount(depositAmount);
  const claimValidation = validateEpochList(claimEpochs);
  const principalValidation = validatePositiveTokenAmount(principalAmount);
  const onBase = chainId === APP_CONFIG.chainId;
  const isWalletReady = Boolean(isConnected && address && onBase);

  async function approveIfNeeded(amount: bigint) {
    if (!address || !publicClient) {
      return;
    }

    const allowance = await publicClient.readContract({
      address: APP_CONFIG.botcoinAddress,
      abi: erc20Abi,
      functionName: "allowance",
      args: [address, APP_CONFIG.defaultPoolAddress],
    });

    if ((allowance as bigint) >= amount) {
      return;
    }

    const approveHash = await writeContractAsync({
      address: APP_CONFIG.botcoinAddress,
      abi: erc20Abi,
      functionName: "approve",
      args: [APP_CONFIG.defaultPoolAddress, amount],
      chainId: APP_CONFIG.chainId,
    });

    setStatusMessage(`Approval sent: ${approveHash}`);
    await publicClient.waitForTransactionReceipt({ hash: approveHash });
  }

  async function submitDeposit() {
    if (!isWalletReady || !address || !publicClient || !depositValidation.available) {
      return;
    }

    const amount = parseUnits(depositAmount, 18);
    await approveIfNeeded(amount);

    const hash = await writeContractAsync({
      address: APP_CONFIG.defaultPoolAddress,
      abi: sharedMiningPoolV2Abi,
      functionName: "deposit",
      args: [amount],
      chainId: APP_CONFIG.chainId,
    });

    setStatusMessage(`Deposit submitted: ${hash}`);
    await publicClient.waitForTransactionReceipt({ hash });
    await onConfirmed();
  }

  async function submitClaimRewards() {
    if (!isWalletReady || !address || !publicClient || !claimValidation.available) {
      return;
    }

    const epochs = parseEpochListInput(claimEpochs).map(BigInt);
    const hash = await writeContractAsync({
      address: APP_CONFIG.defaultPoolAddress,
      abi: sharedMiningPoolV2Abi,
      functionName: "claimMyRewards",
      args: [epochs, address],
      chainId: APP_CONFIG.chainId,
    });

    setStatusMessage(`Reward claim submitted: ${hash}`);
    await publicClient.waitForTransactionReceipt({ hash });
    await onConfirmed();
  }

  async function submitClaimPrincipal() {
    if (!isWalletReady || !address || !publicClient || !principalValidation.available) {
      return;
    }

    const amount = parseUnits(principalAmount, 18);
    const hash = await writeContractAsync({
      address: APP_CONFIG.defaultPoolAddress,
      abi: sharedMiningPoolV2Abi,
      functionName: "claimMyShare",
      args: [amount, address],
      chainId: APP_CONFIG.chainId,
    });

    setStatusMessage(`Principal claim submitted: ${hash}`);
    await publicClient.waitForTransactionReceipt({ hash });
    await onConfirmed();
  }

  const claimAvailability = userSnapshot?.actionAvailability.claimMyRewards;
  const principalAvailability = userSnapshot?.actionAvailability.claimMyShare;

  return (
    <section className="panel flex flex-col gap-5 px-6 py-6 lg:px-8">
      <div className="flex flex-col gap-2">
        <p className="text-xs uppercase tracking-[0.28em] text-ink-soft">Action Center</p>
        <h2 className="text-2xl font-semibold text-ink">Execute only the actions the chain state supports</h2>
        <p className="text-sm leading-6 text-ink-muted">
          Transactions stay disabled until the wallet is on Base mainnet and each action passes its local
          preflight check.
        </p>
      </div>
      <div className="grid gap-4 lg:grid-cols-3">
        <article className="panel-muted flex flex-col gap-4 px-4 py-4">
          <div>
            <p className="text-sm font-semibold text-ink">Deposit BOTCOIN</p>
            <p className="mt-1 text-sm text-ink-muted">Queue principal for next-epoch activation.</p>
          </div>
          <input
            aria-label="Deposit BOTCOIN amount"
            className="rounded-2xl border border-line bg-surface px-4 py-3 text-sm text-ink focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
            onChange={(event) => setDepositAmount(event.target.value)}
            placeholder="25000000"
            value={depositAmount}
          />
          {statusLine(depositValidation.available, depositValidation.reason)}
          <button
            className="rounded-full bg-brand px-4 py-3 text-sm font-semibold text-surface-soft transition-opacity duration-200 hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-45"
            disabled={!depositValidation.available || !isWalletReady || dashboard.phase !== "ActiveStaked"}
            onClick={() => void submitDeposit()}
            type="button"
          >
            {isPending ? "Submitting..." : "Approve Then Deposit"}
          </button>
        </article>
        <article className="panel-muted flex flex-col gap-4 px-4 py-4">
          <div>
            <p className="text-sm font-semibold text-ink">Claim Rewards</p>
            <p className="mt-1 text-sm text-ink-muted">Claim ended epochs using a strictly increasing list.</p>
          </div>
          <input
            aria-label="Claim reward epochs"
            className="rounded-2xl border border-line bg-surface px-4 py-3 text-sm text-ink focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
            onChange={(event) => setClaimEpochs(event.target.value)}
            placeholder="1,2,3"
            value={claimEpochs}
          />
          {statusLine(
            claimValidation.available && Boolean(claimAvailability?.available),
            claimAvailability?.reason ?? claimValidation.reason,
          )}
          <button
            className="rounded-full bg-brand px-4 py-3 text-sm font-semibold text-surface-soft transition-opacity duration-200 hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-45"
            disabled={!claimValidation.available || !claimAvailability?.available || !isWalletReady}
            onClick={() => void submitClaimRewards()}
            type="button"
          >
            {isPending ? "Submitting..." : "Claim Rewards"}
          </button>
        </article>
        <article className="panel-muted flex flex-col gap-4 px-4 py-4">
          <div>
            <p className="text-sm font-semibold text-ink">Claim Principal</p>
            <p className="mt-1 text-sm text-ink-muted">Available only after cooldown completes and the pool returns idle.</p>
          </div>
          <input
            aria-label="Claim principal amount"
            className="rounded-2xl border border-line bg-surface px-4 py-3 text-sm text-ink focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
            onChange={(event) => setPrincipalAmount(event.target.value)}
            placeholder="1000000"
            value={principalAmount}
          />
          {statusLine(
            principalValidation.available && Boolean(principalAvailability?.available),
            principalAvailability?.reason ?? principalValidation.reason,
          )}
          <button
            className="rounded-full bg-brand px-4 py-3 text-sm font-semibold text-surface-soft transition-opacity duration-200 hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-45"
            disabled={!principalValidation.available || !principalAvailability?.available || !isWalletReady}
            onClick={() => void submitClaimPrincipal()}
            type="button"
          >
            {isPending ? "Submitting..." : "Claim Principal"}
          </button>
        </article>
      </div>
      <div className="panel-muted px-4 py-4 text-sm leading-6 text-ink-muted">
        <p className="font-medium text-ink">Permissionless transition visibility</p>
        <p className="mt-2">
          `unstakeAtEpochEnd` is {userSnapshot?.actionAvailability.unstakeAtEpochEnd.available ? "currently" : "not currently"}{" "}
          available. `completeWithdraw` is {userSnapshot?.actionAvailability.completeWithdraw.available ? "currently" : "not currently"}{" "}
          available.
        </p>
        <p className="mt-3 text-xs text-ink-soft">{statusMessage}</p>
      </div>
    </section>
  );
}
