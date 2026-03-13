import {
  decodeEventLog,
  formatUnits,
  type Address,
  type Log,
} from "viem";
import { APP_CONFIG } from "@/config";
import { sharedMiningPoolV2Abi } from "@/lib/abi/sharedMiningPoolV2Abi";
import type { ActivityRecord, HistorySnapshot } from "@/lib/types";
import { readThroughCache } from "./cache";
import { getPublicClient } from "./publicClients";
import { writeServerDebug } from "./logger";

type DecodedLog = {
  eventName: string;
  args: Record<string, unknown>;
  blockNumber: bigint;
  transactionHash: string;
  logIndex: number;
};

function toTokenDisplay(value: bigint | undefined) {
  if (!value) {
    return undefined;
  }

  return formatUnits(value, 18);
}

function decodePoolLog(log: Log): DecodedLog | null {
  try {
    const decoded = decodeEventLog({
      abi: sharedMiningPoolV2Abi,
      data: log.data,
      topics: log.topics,
      strict: false,
    });

    return {
      eventName: decoded.eventName ?? "UnknownEvent",
      args: (decoded.args ?? {}) as Record<string, unknown>,
      blockNumber: log.blockNumber ?? 0n,
      transactionHash: log.transactionHash ?? "0x",
      logIndex: log.logIndex ?? 0,
    };
  } catch {
    return null;
  }
}

function buildActivity(decodedLog: DecodedLog, blockTimestamp: bigint): ActivityRecord {
  const args = decodedLog.args as Record<string, Address | bigint | undefined>;
  const baseRecord = {
    id: `${decodedLog.transactionHash}-${decodedLog.logIndex}`,
    blockNumber: decodedLog.blockNumber?.toString() ?? "0",
    transactionHash: decodedLog.transactionHash ?? "0x",
    timestamp: new Date(Number(blockTimestamp) * 1000).toISOString(),
  };

  switch (decodedLog.eventName) {
    case "Deposited":
      return {
        ...baseRecord,
        type: "deposit",
        title: "Depositor queued BOTCOIN for next epoch",
        summary: `Deposit of ${toTokenDisplay(args.amount as bigint)} BOTCOIN scheduled for activation at epoch ${(args.activationEpoch as bigint).toString()}.`,
        actor: "Depositor",
        amount: toTokenDisplay(args.amount as bigint),
        epoch: (args.activationEpoch as bigint).toString(),
        address: args.user as Address,
      };
    case "SharesActivated":
      return {
        ...baseRecord,
        type: "shares_activated",
        title: "Queued shares activated",
        summary: `Pool activated ${toTokenDisplay(args.activatedShares as bigint)} BOTCOIN worth of shares.`,
        actor: "Pool",
        amount: toTokenDisplay(args.activatedShares as bigint),
        epoch: (args.epoch as bigint).toString(),
      };
    case "ReceiptForwarded":
      return {
        ...baseRecord,
        type: "receipt_forwarded",
        title: "Mining receipt forwarded",
        summary: `Pool forwarded mining calldata and increased credits by ${(args.deltaCredits as bigint).toString()}.`,
        actor: "Operator",
        epoch: (args.epoch as bigint).toString(),
      };
    case "RegularRewardsClaimed":
      return {
        ...baseRecord,
        type: "regular_claimed",
        title: "Regular rewards claimed",
        summary: `Regular epoch rewards were claimed and split into net reward ${toTokenDisplay(args.netReward as bigint)} BOTCOIN.`,
        actor: "Relayer / Anyone",
        epoch: (args.epoch as bigint).toString(),
        amount: toTokenDisplay(args.grossReward as bigint),
        feeAmount: toTokenDisplay(args.feeAmount as bigint),
        netReward: toTokenDisplay(args.netReward as bigint),
      };
    case "BonusRewardsClaimed":
      return {
        ...baseRecord,
        type: "bonus_claimed",
        title: "Bonus rewards claimed",
        summary: `Bonus epoch rewards were claimed and split into net reward ${toTokenDisplay(args.netReward as bigint)} BOTCOIN.`,
        actor: "Relayer / Anyone",
        epoch: (args.epoch as bigint).toString(),
        amount: toTokenDisplay(args.grossReward as bigint),
        feeAmount: toTokenDisplay(args.feeAmount as bigint),
        netReward: toTokenDisplay(args.netReward as bigint),
      };
    case "UserRewardsClaimed":
      return {
        ...baseRecord,
        type: "user_rewards_claimed",
        title: "Depositor claimed rewards",
        summary: `Depositor claimed ${toTokenDisplay(args.payoutAmount as bigint)} BOTCOIN in rewards.`,
        actor: "Depositor",
        epoch: (args.epoch as bigint).toString(),
        amount: toTokenDisplay(args.payoutAmount as bigint),
        address: args.user as Address,
      };
    case "UnstakeRequested":
      return {
        ...baseRecord,
        type: "unstake_requested",
        title: "Epoch-end unstake requested",
        summary: "Pool requested a full unstake and entered cooldown.",
        actor: "Anyone",
        epoch: (args.epoch as bigint).toString(),
        address: args.caller as Address,
      };
    case "UnstakeFinalized":
      return {
        ...baseRecord,
        type: "unstake_finalized",
        title: "Cooldown withdraw finalized",
        summary: "Pool completed the cooldown withdraw back into pool custody.",
        actor: "Anyone",
        epoch: (args.epoch as bigint).toString(),
        address: args.caller as Address,
      };
    case "Restaked":
      return {
        ...baseRecord,
        type: "restaked",
        title: "Principal restaked",
        summary: `Pool restaked ${toTokenDisplay(args.amount as bigint)} BOTCOIN of principal.`,
        actor: "Anyone",
        epoch: (args.epoch as bigint).toString(),
        amount: toTokenDisplay(args.amount as bigint),
        address: args.caller as Address,
      };
    case "PrincipalStaked":
      return {
        ...baseRecord,
        type: "principal_staked",
        title: "Available principal staked",
        summary: `Pool staked ${toTokenDisplay(args.amount as bigint)} BOTCOIN toward the principal target.`,
        actor: "Anyone",
        epoch: (args.epoch as bigint).toString(),
        amount: toTokenDisplay(args.amount as bigint),
        address: args.caller as Address,
      };
    case "PrincipalWithdrawn":
      return {
        ...baseRecord,
        type: "principal_withdrawn",
        title: "Depositor withdrew principal",
        summary: `Depositor withdrew ${toTokenDisplay(args.amount as bigint)} BOTCOIN of principal.`,
        actor: "Depositor",
        epoch: (args.epoch as bigint).toString(),
        amount: toTokenDisplay(args.amount as bigint),
        address: args.user as Address,
      };
    default:
      return {
        ...baseRecord,
        type: "unknown",
        title: decodedLog.eventName,
        summary: "Unmapped pool event captured from the live contract.",
        actor: "Pool",
      };
  }
}

export async function getHistorySnapshot(limit = 50): Promise<HistorySnapshot> {
  const client = getPublicClient();
  const latestBlock = await client.getBlockNumber();
  const cacheKey = `history:${latestBlock.toString()}:${limit}`;

  return readThroughCache(cacheKey, 2_000, async () => {
    try {
      const logs = await client.getLogs({
        address: APP_CONFIG.defaultPoolAddress,
        fromBlock: APP_CONFIG.deploymentStartBlock,
        toBlock: latestBlock,
      });

      const decodedLogs = logs
        .map((log: Log) => decodePoolLog(log))
        .filter((log): log is DecodedLog => log !== null);

      const uniqueBlockNumbers = [...new Set(decodedLogs.map((log) => log.blockNumber))];
      const blockMap = new Map<bigint, bigint>();

      await Promise.all(
        uniqueBlockNumbers.map(async (blockNumber) => {
          const block = await client.getBlock({ blockNumber });
          blockMap.set(blockNumber, block.timestamp);
        }),
      );

      const events = decodedLogs
        .map((log) => buildActivity(log, blockMap.get(log.blockNumber) ?? 0n))
        .sort((left: ActivityRecord, right: ActivityRecord) => {
          if (left.blockNumber === right.blockNumber) {
            return right.id.localeCompare(left.id);
          }

          return Number(right.blockNumber) - Number(left.blockNumber);
        });

      return {
        blockNumber: latestBlock.toString(),
        observedAt: new Date().toISOString(),
        totalEvents: events.length,
        events: events.slice(0, limit),
      };
    } catch (error) {
      await writeServerDebug("historySnapshot", "读取链上历史失败，返回空历史。", {
        error: error instanceof Error ? error.message : String(error),
      });

      return {
        blockNumber: latestBlock.toString(),
        observedAt: new Date().toISOString(),
        totalEvents: 0,
        events: [],
      };
    }
  });
}
