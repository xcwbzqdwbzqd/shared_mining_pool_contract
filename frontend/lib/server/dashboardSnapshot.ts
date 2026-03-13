import { formatUnits } from "viem";
import { APP_CONFIG } from "@/config";
import { erc20Abi } from "@/lib/abi/erc20Abi";
import { miningV2Abi } from "@/lib/abi/miningV2Abi";
import { sharedMiningPoolV2Abi } from "@/lib/abi/sharedMiningPoolV2Abi";
import type { DashboardSnapshot, PhaseLabel } from "@/lib/types";
import { readThroughCache } from "./cache";
import { buildPublicFlowSteps } from "./flowSnapshot";
import { getHistorySnapshot } from "./historySnapshot";
import { getPublicClient } from "./publicClients";
import { writeServerDebug } from "./logger";

const PHASE_LABELS: Record<number, PhaseLabel> = {
  0: "ActiveStaked",
  1: "Cooldown",
  2: "WithdrawnIdle",
};

const DASHBOARD_CACHE_KEY = "dashboard:latest";
const DASHBOARD_CACHE_TTL_MS = 2_000;
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

function toDisplay(value: bigint) {
  return formatUnits(value, 18);
}

async function readContractWithFallback<T>(
  client: ReturnType<typeof getPublicClient>,
  label: string,
  request: Parameters<ReturnType<typeof getPublicClient>["readContract"]>[0],
  fallback: T,
): Promise<T> {
  try {
    return (await client.readContract(request)) as T;
  } catch (error) {
    await writeServerDebug("dashboardSnapshot", "链上聚合字段读取失败，使用回退值。", {
      label,
      error: error instanceof Error ? error.message : String(error),
    });

    return fallback;
  }
}

async function readBlockNumberWithFallback(
  client: ReturnType<typeof getPublicClient>,
  fallback: bigint,
): Promise<bigint> {
  try {
    return await client.getBlockNumber();
  } catch (error) {
    await writeServerDebug("dashboardSnapshot", "读取最新区块失败，使用回退值。", {
      error: error instanceof Error ? error.message : String(error),
    });

    return fallback;
  }
}

async function readHistoryWithFallback(limit: number) {
  try {
    return await getHistorySnapshot(limit);
  } catch (error) {
    await writeServerDebug("dashboardSnapshot", "读取历史快照失败，返回空历史。", {
      error: error instanceof Error ? error.message : String(error),
    });

    return {
      blockNumber: "0",
      observedAt: new Date().toISOString(),
      totalEvents: 0,
      events: [],
    };
  }
}

export async function getDashboardSnapshot(): Promise<DashboardSnapshot> {
  return readThroughCache(DASHBOARD_CACHE_KEY, DASHBOARD_CACHE_TTL_MS, async () => {
    const client = getPublicClient();
    const [currentEpoch, head, recentHistory] = await Promise.all([
      readContractWithFallback(
        client,
        "currentEpoch",
        {
          address: APP_CONFIG.miningAddress,
          abi: miningV2Abi,
          functionName: "currentEpoch",
        },
        0n,
      ),
      readBlockNumberWithFallback(client, 0n),
      readHistoryWithFallback(12),
    ]);

    const [
      phase,
      lastSettledEpoch,
      lastUnstakeEpoch,
      lastRestakeEpoch,
      unstakeAvailableAtEpoch,
      totalActiveShares,
      totalPrincipalLiability,
      totalNetRewardsAccrued,
      totalRewardsPaid,
      rewardReserve,
      feeBps,
      feeRecipient,
      operator,
      receiptSubmitSelector,
      maxEpochsPerClaim,
      stakedAmount,
      withdrawableAt,
      poolTokenBalance,
      currentEpochCredits,
    ] = await Promise.all([
      readContractWithFallback(
        client,
        "phase",
        {
          address: APP_CONFIG.defaultPoolAddress,
          abi: sharedMiningPoolV2Abi,
          functionName: "phase",
        },
        0n,
      ),
      readContractWithFallback(
        client,
        "lastSettledEpoch",
        {
          address: APP_CONFIG.defaultPoolAddress,
          abi: sharedMiningPoolV2Abi,
          functionName: "lastSettledEpoch",
        },
        0n,
      ),
      readContractWithFallback(
        client,
        "lastUnstakeEpoch",
        {
          address: APP_CONFIG.defaultPoolAddress,
          abi: sharedMiningPoolV2Abi,
          functionName: "lastUnstakeEpoch",
        },
        0n,
      ),
      readContractWithFallback(
        client,
        "lastRestakeEpoch",
        {
          address: APP_CONFIG.defaultPoolAddress,
          abi: sharedMiningPoolV2Abi,
          functionName: "lastRestakeEpoch",
        },
        0n,
      ),
      readContractWithFallback(
        client,
        "unstakeAvailableAtEpoch",
        {
          address: APP_CONFIG.defaultPoolAddress,
          abi: sharedMiningPoolV2Abi,
          functionName: "unstakeAvailableAtEpoch",
        },
        0n,
      ),
      readContractWithFallback(
        client,
        "totalActiveShares",
        {
          address: APP_CONFIG.defaultPoolAddress,
          abi: sharedMiningPoolV2Abi,
          functionName: "totalActiveShares",
        },
        0n,
      ),
      readContractWithFallback(
        client,
        "totalPrincipalLiability",
        {
          address: APP_CONFIG.defaultPoolAddress,
          abi: sharedMiningPoolV2Abi,
          functionName: "totalPrincipalLiability",
        },
        0n,
      ),
      readContractWithFallback(
        client,
        "totalNetRewardsAccrued",
        {
          address: APP_CONFIG.defaultPoolAddress,
          abi: sharedMiningPoolV2Abi,
          functionName: "totalNetRewardsAccrued",
        },
        0n,
      ),
      readContractWithFallback(
        client,
        "totalRewardsPaid",
        {
          address: APP_CONFIG.defaultPoolAddress,
          abi: sharedMiningPoolV2Abi,
          functionName: "totalRewardsPaid",
        },
        0n,
      ),
      readContractWithFallback(
        client,
        "rewardReserve",
        {
          address: APP_CONFIG.defaultPoolAddress,
          abi: sharedMiningPoolV2Abi,
          functionName: "rewardReserve",
        },
        0n,
      ),
      readContractWithFallback(
        client,
        "feeBps",
        {
          address: APP_CONFIG.defaultPoolAddress,
          abi: sharedMiningPoolV2Abi,
          functionName: "feeBps",
        },
        0,
      ),
      readContractWithFallback(
        client,
        "feeRecipient",
        {
          address: APP_CONFIG.defaultPoolAddress,
          abi: sharedMiningPoolV2Abi,
          functionName: "feeRecipient",
        },
        ZERO_ADDRESS,
      ),
      readContractWithFallback(
        client,
        "operator",
        {
          address: APP_CONFIG.defaultPoolAddress,
          abi: sharedMiningPoolV2Abi,
          functionName: "operator",
        },
        ZERO_ADDRESS,
      ),
      readContractWithFallback(
        client,
        "receiptSubmitSelector",
        {
          address: APP_CONFIG.defaultPoolAddress,
          abi: sharedMiningPoolV2Abi,
          functionName: "receiptSubmitSelector",
        },
        "0x00000000",
      ),
      readContractWithFallback(
        client,
        "maxEpochsPerClaim",
        {
          address: APP_CONFIG.defaultPoolAddress,
          abi: sharedMiningPoolV2Abi,
          functionName: "maxEpochsPerClaim",
        },
        0,
      ),
      readContractWithFallback(
        client,
        "stakedAmount",
        {
          address: APP_CONFIG.miningAddress,
          abi: miningV2Abi,
          functionName: "stakedAmount",
          args: [APP_CONFIG.defaultPoolAddress],
        },
        0n,
      ),
      readContractWithFallback(
        client,
        "withdrawableAt",
        {
          address: APP_CONFIG.miningAddress,
          abi: miningV2Abi,
          functionName: "withdrawableAt",
          args: [APP_CONFIG.defaultPoolAddress],
        },
        0n,
      ),
      readContractWithFallback(
        client,
        "poolTokenBalance",
        {
          address: APP_CONFIG.botcoinAddress,
          abi: erc20Abi,
          functionName: "balanceOf",
          args: [APP_CONFIG.defaultPoolAddress],
        },
        0n,
      ),
      readContractWithFallback(
        client,
        "currentEpochCredits",
        {
          address: APP_CONFIG.miningAddress,
          abi: miningV2Abi,
          functionName: "credits",
          args: [currentEpoch, APP_CONFIG.defaultPoolAddress],
        },
        0n,
      ),
    ]);

    const phaseLabel = PHASE_LABELS[Number(phase)] ?? "ActiveStaked";

    const snapshotBase = {
      currentEpoch: currentEpoch.toString(),
      phase: phaseLabel,
      stakedAmount: toDisplay(stakedAmount),
      poolTokenBalance: toDisplay(poolTokenBalance),
      withdrawableAt: withdrawableAt.toString(),
      rewardReserve: toDisplay(rewardReserve),
      totalPrincipalLiability: toDisplay(totalPrincipalLiability),
      totalActiveShares: toDisplay(totalActiveShares),
      totalNetRewardsAccrued: toDisplay(totalNetRewardsAccrued),
      totalRewardsPaid: toDisplay(totalRewardsPaid),
      lastSettledEpoch: lastSettledEpoch.toString(),
      lastUnstakeEpoch: lastUnstakeEpoch.toString(),
      lastRestakeEpoch: lastRestakeEpoch.toString(),
      unstakeAvailableAtEpoch: unstakeAvailableAtEpoch.toString(),
      feeBps: Number(feeBps),
      feeRecipient,
      operator,
      receiptSubmitSelector,
      maxEpochsPerClaim: Number(maxEpochsPerClaim),
      currentEpochCredits: currentEpochCredits.toString(),
    } satisfies Omit<
      DashboardSnapshot,
      "blockNumber" | "observedAt" | "flowSteps" | "recentActivity" | "historyEventCount"
    >;

    return {
      ...snapshotBase,
      blockNumber: head.toString(),
      observedAt: new Date().toISOString(),
      flowSteps: buildPublicFlowSteps(snapshotBase),
      recentActivity: recentHistory.events,
      historyEventCount: recentHistory.totalEvents,
    };
  });
}
