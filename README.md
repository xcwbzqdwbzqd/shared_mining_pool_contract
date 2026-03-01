# BOTCOIN Shared Mining Pool V2 (Foundry)

This repository contains a V2-only pooled mining contract implementation for BOTCOIN on Base.

## Core Contract

- `src/SharedMiningPoolV2.sol`

## Supported External Interfaces

- `src/interfaces/IMiningV2.sol`
- `src/interfaces/IBonusEpoch.sol`
- `src/interfaces/IERC20Minimal.sol`

## V2 Design Goals

- The pool contract is the miner and staker on mining V2.
- User principal accounting is deterministic and on-chain.
- Critical principal return transitions are permissionless:
  - `unstakeAtEpochEnd()`
  - `finalizeWithdraw()`
  - `restake()`
- Reward distribution is epoch-based and claimable by users without operator approval.
- Bonus rewards are claimable through BonusEpoch and distributed via the same share-index accounting path.
- Operator trust is limited to off-chain solving and receipt forwarding only.

## Mainnet Reference Addresses

- Mining V2: `0xcF5F2D541EEb0fb4cA35F1973DE5f2B02dfC3716`
- BonusEpoch: `0xA185fE194A7F603b7287BC0abAeBA1b896a36Ba8`
- BOTCOIN token: `0xA601877977340862Ca67f816eb079958E5bd0BA3`

## Deployment Script

- `script/SharedMiningPoolV2.s.sol`

## Test Layout (V2 Only)

- Unit: `test/unit/*V2*.t.sol`
- Integration: `test/integration/*V2*.t.sol`
- Feature: `test/feature/*V2*.t.sol`
- Security: `test/security/*V2*.t.sol`
- Fuzz: `test/fuzz/*V2*.t.sol`
- Invariant-style: `test/invariant/*V2*.t.sol`

## Build and Test

Format:

```bash
cd shared_mining_pool_contract && forge fmt
```

Build:

```bash
cd shared_mining_pool_contract && forge build
```

Run all tests:

```bash
cd shared_mining_pool_contract && forge test -vvv
```

Run all tests and write a single log file:

```bash
cd shared_mining_pool_contract && forge test -vvv 2>&1 | tee ./shared_mining_pool_contract.log
```


