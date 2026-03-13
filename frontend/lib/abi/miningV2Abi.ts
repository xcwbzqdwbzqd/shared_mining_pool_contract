export const miningV2Abi = [
  {
    type: "function",
    name: "currentEpoch",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint64" }],
  },
  {
    type: "function",
    name: "credits",
    stateMutability: "view",
    inputs: [
      { name: "epoch", type: "uint64" },
      { name: "miner", type: "address" },
    ],
    outputs: [{ name: "", type: "uint64" }],
  },
  {
    type: "function",
    name: "stakedAmount",
    stateMutability: "view",
    inputs: [{ name: "miner", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "withdrawableAt",
    stateMutability: "view",
    inputs: [{ name: "miner", type: "address" }],
    outputs: [{ name: "", type: "uint64" }],
  },
] as const;
