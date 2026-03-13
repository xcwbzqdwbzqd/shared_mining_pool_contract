import { FLOW_LABELS } from "@/config";
import type { DashboardSnapshot, FlowStep } from "@/lib/types";

export function buildPublicFlowSteps(snapshot: Pick<
  DashboardSnapshot,
  | "phase"
  | "stakedAmount"
  | "totalPrincipalLiability"
  | "currentEpochCredits"
  | "totalNetRewardsAccrued"
  | "totalRewardsPaid"
  | "unstakeAvailableAtEpoch"
  | "currentEpoch"
>): FlowStep[] {
  const hasPrincipal = Number(snapshot.totalPrincipalLiability) > 0;
  const hasStake = Number(snapshot.stakedAmount) > 0;
  const hasCurrentCredits = Number(snapshot.currentEpochCredits) > 0;
  const hasRewardsAccrued = Number(snapshot.totalNetRewardsAccrued) > 0;
  const hasUnpaidRewards =
    Number(snapshot.totalNetRewardsAccrued) > Number(snapshot.totalRewardsPaid);
  const isCooldown = snapshot.phase === "Cooldown";
  const isWithdrawnIdle = snapshot.phase === "WithdrawnIdle";
  const isActive = snapshot.phase === "ActiveStaked";
  const canUnstakeNow = Number(snapshot.currentEpoch) >= Number(snapshot.unstakeAvailableAtEpoch);

  return [
    {
      step: 1,
      actor: "Depositor",
      title: FLOW_LABELS[0],
      method: "deposit(uint256)",
      onChainEffect: "Queues principal for next-epoch share activation.",
      status: hasPrincipal ? "Done" : isActive ? "Available Now" : "Blocked By Protocol Condition",
      reason: isActive
        ? "Deposits are open while the pool remains actively staked."
        : "Deposits are disabled unless the pool is in ActiveStaked phase.",
      nextActor: "Pool",
    },
    {
      step: 2,
      actor: "Pool",
      title: FLOW_LABELS[1],
      method: "stakeAvailablePrincipal()",
      onChainEffect: "Moves unstaked principal into Mining V2.",
      status: hasStake ? "Done" : hasPrincipal && isActive ? "Available Now" : "Blocked By Protocol Condition",
      reason: hasStake
        ? "The pool already has principal staked in Mining V2."
        : "The pool can only stake principal while the lifecycle phase remains ActiveStaked.",
      nextActor: "Operator",
    },
    {
      step: 3,
      actor: "Operator",
      title: FLOW_LABELS[2],
      method: "Off-chain only",
      onChainEffect: "Produces signed calldata for mining submission.",
      status: hasStake ? "Waiting On Other Actor" : "Blocked By Protocol Condition",
      reason: hasStake
        ? "The operator can solve challenges whenever the pool remains actively staked."
        : "The operator cannot meaningfully solve while the pool is not staked.",
      nextActor: "Operator",
    },
    {
      step: 4,
      actor: "Operator",
      title: FLOW_LABELS[3],
      method: "submitToMining(bytes)",
      onChainEffect: "Forwards mining receipt calldata through the pool contract.",
      status: hasCurrentCredits ? "Done" : hasStake && isActive ? "Waiting On Other Actor" : "Blocked By Protocol Condition",
      reason: hasCurrentCredits
        ? "The pool has already increased credits in the current epoch."
        : "Only the fixed operator can send allowed mining calldata while the pool is actively staked.",
      nextActor: "Pool",
    },
    {
      step: 5,
      actor: "Pool",
      title: FLOW_LABELS[4],
      method: "mining.submitReceipt(...)",
      onChainEffect: "Credits accrue to the pool contract address.",
      status: hasCurrentCredits ? "Done" : hasStake ? "Waiting On Other Actor" : "Blocked By Protocol Condition",
      reason: hasCurrentCredits
        ? "Receipt forwarding has already increased pool credits."
        : "Credits appear only after a successful operator submission.",
      nextActor: "Relayer / Anyone",
    },
    {
      step: 6,
      actor: "Relayer / Anyone",
      title: FLOW_LABELS[5],
      method: "triggerClaim(uint64[])",
      onChainEffect: "Pulls regular epoch rewards into the pool balance.",
      status: hasRewardsAccrued ? "Done" : "Waiting On Other Actor",
      reason: hasRewardsAccrued
        ? "Regular or bonus rewards have already been accounted for at least once."
        : "Regular claims become meaningful only after ended epochs are funded and claimable.",
      nextActor: "Pool",
    },
    {
      step: 7,
      actor: "Pool",
      title: FLOW_LABELS[6],
      method: "mining.claim(uint64[])",
      onChainEffect: "Transfers regular BOTCOIN rewards to the pool.",
      status: hasRewardsAccrued ? "Done" : "Waiting On Other Actor",
      reason: hasRewardsAccrued
        ? "Pool accounting already shows net rewards accrued."
        : "Pool reward receipts depend on the claim call and epoch funding.",
      nextActor: "Relayer / Anyone",
    },
    {
      step: 8,
      actor: "Relayer / Anyone",
      title: FLOW_LABELS[7],
      method: "triggerBonusClaim(uint64[])",
      onChainEffect: "Pulls bonus rewards for eligible epochs.",
      status: hasRewardsAccrued ? "Done" : "Waiting On Other Actor",
      reason: "Bonus claim availability depends on epoch eligibility and BonusEpoch claim windows.",
      nextActor: "Pool",
    },
    {
      step: 9,
      actor: "Pool",
      title: FLOW_LABELS[8],
      method: "bonusEpoch.claimBonus(uint64[])",
      onChainEffect: "Transfers bonus BOTCOIN rewards to the pool.",
      status: hasRewardsAccrued ? "Done" : "Waiting On Other Actor",
      reason: "Bonus tokens arrive only after a successful bonus claim for an eligible epoch.",
      nextActor: "Pool",
    },
    {
      step: 10,
      actor: "Pool",
      title: FLOW_LABELS[9],
      method: "Internal accounting",
      onChainEffect: "Accrues per-epoch reward indexes for depositors.",
      status: hasRewardsAccrued ? "Done" : "Waiting On Other Actor",
      reason: hasRewardsAccrued
        ? "The pool has recorded net rewards into on-chain accounting."
        : "Distribution accounting appears only after reward tokens reach the pool.",
      nextActor: "Depositor",
    },
    {
      step: 11,
      actor: "Depositor",
      title: FLOW_LABELS[10],
      method: "claimMyRewards(uint64[],address)",
      onChainEffect: "Transfers claimable reward balance to the chosen recipient.",
      status: hasUnpaidRewards ? "Available Now" : "Waiting On Other Actor",
      reason: hasUnpaidRewards
        ? "Depositor-specific availability depends on the connected address and ended rewarded epochs."
        : "Reward claims become meaningful only after the pool has accrued reward indexes.",
      nextActor: "Anyone or Depositor",
    },
    {
      step: 12,
      actor: "Anyone",
      title: FLOW_LABELS[11],
      method: "unstakeAtEpochEnd()",
      onChainEffect: "Requests the full pool unstake at the configured boundary.",
      status:
        isActive && hasStake && canUnstakeNow
          ? "Available Now"
          : isCooldown || isWithdrawnIdle
            ? "Done"
            : "Blocked By Protocol Condition",
      reason: isActive
        ? "This call is only valid once the configured epoch boundary has been reached."
        : "The pool has already left the ActiveStaked phase.",
      nextActor: "Anyone",
    },
    {
      step: 13,
      actor: "Anyone",
      title: FLOW_LABELS[12],
      method: "completeWithdraw()",
      onChainEffect: "Moves principal from Mining V2 back into pool custody after cooldown.",
      status: isWithdrawnIdle ? "Done" : isCooldown ? "Available Now" : "Blocked By Protocol Condition",
      reason: isCooldown
        ? "This becomes available after Mining V2 reports a finished cooldown timestamp."
        : "The pool must first enter Cooldown through an epoch-end unstake.",
      nextActor: "Depositor",
    },
    {
      step: 14,
      actor: "Depositor",
      title: FLOW_LABELS[13],
      method: "claimMyShare(uint256,address)",
      onChainEffect: "Withdraws principal from pool custody or prepares for the next deposit cycle.",
      status: isWithdrawnIdle ? "Available Now" : "Blocked By Protocol Condition",
      reason: isWithdrawnIdle
        ? "Depositors can withdraw principal only after the pool is back in WithdrawnIdle."
        : "Principal remains locked in mining until cooldown is completed.",
      nextActor: "Depositor",
    },
  ];
}
