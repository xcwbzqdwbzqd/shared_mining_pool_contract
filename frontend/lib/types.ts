export type PhaseLabel = "ActiveStaked" | "Cooldown" | "WithdrawnIdle";

export type FlowStatus =
  | "Done"
  | "Available Now"
  | "Waiting On Other Actor"
  | "Blocked By Protocol Condition";

export type ActivityType =
  | "deposit"
  | "shares_activated"
  | "receipt_forwarded"
  | "regular_claimed"
  | "bonus_claimed"
  | "user_rewards_claimed"
  | "unstake_requested"
  | "unstake_finalized"
  | "restaked"
  | "principal_staked"
  | "principal_withdrawn"
  | "unknown";

export interface ActivityRecord {
  id: string;
  type: ActivityType;
  title: string;
  summary: string;
  actor: string;
  blockNumber: string;
  transactionHash: string;
  timestamp: string;
  epoch?: string;
  amount?: string;
  feeAmount?: string;
  netReward?: string;
  address?: string;
}

export interface StepAvailability {
  available: boolean;
  reason: string;
}

export interface FlowStep {
  step: number;
  actor: string;
  title: string;
  method: string;
  onChainEffect: string;
  status: FlowStatus;
  reason: string;
  nextActor: string;
}

export interface DashboardSnapshot {
  blockNumber: string;
  observedAt: string;
  currentEpoch: string;
  phase: PhaseLabel;
  stakedAmount: string;
  poolTokenBalance: string;
  withdrawableAt: string;
  rewardReserve: string;
  totalPrincipalLiability: string;
  totalActiveShares: string;
  totalNetRewardsAccrued: string;
  totalRewardsPaid: string;
  lastSettledEpoch: string;
  lastUnstakeEpoch: string;
  lastRestakeEpoch: string;
  unstakeAvailableAtEpoch: string;
  feeBps: number;
  feeRecipient: string;
  operator: string;
  receiptSubmitSelector: string;
  maxEpochsPerClaim: number;
  currentEpochCredits: string;
  flowSteps: FlowStep[];
  recentActivity: ActivityRecord[];
  historyEventCount: number;
}

export interface HistorySnapshot {
  blockNumber: string;
  observedAt: string;
  totalEvents: number;
  events: ActivityRecord[];
}

export interface UserSnapshot {
  address: string;
  blockNumber: string;
  observedAt: string;
  walletBalance: string;
  allowance: string;
  principal: string;
  withdrawnPrincipal: string;
  activeShares: string;
  pendingSharesNextEpoch: string;
  claimableRewards: string;
  claimableEpochs: string[];
  canViewOperator: boolean;
  actionAvailability: Record<string, StepAvailability>;
}

export interface HeadSnapshot {
  blockNumber: string;
  observedAt: string;
}
