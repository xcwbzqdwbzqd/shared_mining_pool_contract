import { formatUnits, getAddress, isAddress } from "viem";
import { APP_CONFIG } from "@/config";
import { erc20Abi } from "@/lib/abi/erc20Abi";
import { sharedMiningPoolV2Abi } from "@/lib/abi/sharedMiningPoolV2Abi";
import type { StepAvailability, UserSnapshot } from "@/lib/types";
import { getDashboardSnapshot } from "./dashboardSnapshot";
import { getHistorySnapshot } from "./historySnapshot";
import { getPublicClient } from "./publicClients";

const ACC_PRECISION = 10n ** 36n;

function toDisplay(value: bigint) {
  return formatUnits(value, 18);
}

function makeAvailability(available: boolean, reason: string): StepAvailability {
  return {
    available,
    reason,
  };
}

export async function getUserSnapshot(addressInput: string): Promise<UserSnapshot> {
  if (!isAddress(addressInput)) {
    throw new Error("Invalid address");
  }

  const address = getAddress(addressInput);
  const client = getPublicClient();
  const dashboard = await getDashboardSnapshot();
  const history = await getHistorySnapshot(200);
  const currentEpoch = BigInt(dashboard.currentEpoch);
  const nextEpoch = currentEpoch + 1n;

  const [
    principal,
    withdrawnPrincipal,
    activeShares,
    pendingSharesNextEpoch,
    walletBalance,
    allowance,
  ] = await Promise.all([
    client.readContract({
      address: APP_CONFIG.defaultPoolAddress,
      abi: sharedMiningPoolV2Abi,
      functionName: "userPrincipal",
      args: [address],
    }),
    client.readContract({
      address: APP_CONFIG.defaultPoolAddress,
      abi: sharedMiningPoolV2Abi,
      functionName: "userWithdrawnPrincipal",
      args: [address],
    }),
    client.readContract({
      address: APP_CONFIG.defaultPoolAddress,
      abi: sharedMiningPoolV2Abi,
      functionName: "userSharesAtEpoch",
      args: [address, currentEpoch],
    }),
    client.readContract({
      address: APP_CONFIG.defaultPoolAddress,
      abi: sharedMiningPoolV2Abi,
      functionName: "userPendingSharesByEpoch",
      args: [address, nextEpoch],
    }),
    client.readContract({
      address: APP_CONFIG.botcoinAddress,
      abi: erc20Abi,
      functionName: "balanceOf",
      args: [address],
    }),
    client.readContract({
      address: APP_CONFIG.botcoinAddress,
      abi: erc20Abi,
      functionName: "allowance",
      args: [address, APP_CONFIG.defaultPoolAddress],
    }),
  ]);

  const rewardEpochs = [...new Set(history.events.map((event) => event.epoch).filter(Boolean))] as string[];

  const rewardReads = await Promise.all(
    rewardEpochs.map(async (epoch) => {
      const epochId = BigInt(epoch);
      const [shares, accReward, rewardDebt] = await Promise.all([
        client.readContract({
          address: APP_CONFIG.defaultPoolAddress,
          abi: sharedMiningPoolV2Abi,
          functionName: "userSharesAtEpoch",
          args: [address, epochId],
        }),
        client.readContract({
          address: APP_CONFIG.defaultPoolAddress,
          abi: sharedMiningPoolV2Abi,
          functionName: "epochAccRewardPerShare",
          args: [epochId],
        }),
        client.readContract({
          address: APP_CONFIG.defaultPoolAddress,
          abi: sharedMiningPoolV2Abi,
          functionName: "userRewardDebt",
          args: [address, epochId],
        }),
      ]);

      const accrued = ((shares as bigint) * (accReward as bigint)) / ACC_PRECISION;
      const debt = rewardDebt as bigint;
      const pending = accrued > debt ? accrued - debt : 0n;

      return {
        epoch,
        pending,
      };
    }),
  );

  const claimableEpochs = rewardReads
    .filter((item) => item.pending > 0n)
    .map((item) => item.epoch);

  const claimableRewards = rewardReads.reduce((sum, item) => sum + item.pending, 0n);
  const canDeposit = dashboard.phase === "ActiveStaked";
  const canClaimShare = dashboard.phase === "WithdrawnIdle" && (principal as bigint) > 0n;
  const canClaimRewards = claimableRewards > 0n;
  const canUnstake =
    dashboard.phase === "ActiveStaked" &&
    Number(dashboard.currentEpoch) >= Number(dashboard.unstakeAvailableAtEpoch) &&
    Number(dashboard.stakedAmount) > 0;
  const canCompleteWithdraw =
    dashboard.phase === "Cooldown" &&
    Number(dashboard.withdrawableAt) > 0 &&
    Date.now() / 1000 >= Number(dashboard.withdrawableAt);

  return {
    address,
    blockNumber: dashboard.blockNumber,
    observedAt: new Date().toISOString(),
    walletBalance: toDisplay(walletBalance as bigint),
    allowance: toDisplay(allowance as bigint),
    principal: toDisplay(principal as bigint),
    withdrawnPrincipal: toDisplay(withdrawnPrincipal as bigint),
    activeShares: toDisplay(activeShares as bigint),
    pendingSharesNextEpoch: toDisplay(pendingSharesNextEpoch as bigint),
    claimableRewards: toDisplay(claimableRewards),
    claimableEpochs,
    canViewOperator: address === APP_CONFIG.operatorAddress,
    actionAvailability: {
      deposit: makeAvailability(
        canDeposit,
        canDeposit
          ? "Pool is actively staked, so new deposits can queue for the next epoch."
          : "Deposits are closed unless the pool is in ActiveStaked phase.",
      ),
      claimMyRewards: makeAvailability(
        canClaimRewards,
        canClaimRewards
          ? "This address has positive pending rewards on at least one rewarded epoch."
          : "No pending reward debt delta is currently available for this address.",
      ),
      claimMyShare: makeAvailability(
        canClaimShare,
        canClaimShare
          ? "The pool is back in WithdrawnIdle and this address still has principal."
          : "Principal can only be withdrawn after cooldown completes and the pool returns to WithdrawnIdle.",
      ),
      unstakeAtEpochEnd: makeAvailability(
        canUnstake,
        canUnstake
          ? "The configured epoch boundary has been reached, so anyone can request the full unstake."
          : "This becomes available only once the pool is active, staked, and the unstake epoch boundary is reached.",
      ),
      completeWithdraw: makeAvailability(
        canCompleteWithdraw,
        canCompleteWithdraw
          ? "Mining V2 cooldown is complete, so anyone can finalize the pool withdrawal."
          : "This becomes available only after the pool is in Cooldown and Mining V2 reports the cooldown timestamp as finished.",
      ),
    },
  };
}
