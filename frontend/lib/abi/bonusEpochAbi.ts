export const bonusEpochAbi = [
  {
    type: "function",
    name: "isBonusEpoch",
    stateMutability: "view",
    inputs: [{ name: "epoch", type: "uint64" }],
    outputs: [{ name: "", type: "bool" }],
  },
  {
    type: "function",
    name: "bonusClaimsOpen",
    stateMutability: "view",
    inputs: [{ name: "epoch", type: "uint64" }],
    outputs: [{ name: "", type: "bool" }],
  },
] as const;
