# BOTCOIN Shared Mining Pool Contract (Foundry)

This repository under `shared_mining_pool_contract/shared_mining_pool_contract` contains a deployable shared mining pool contract for Base:

- Depositors deposit BOTCOIN into the pool contract (miner address = contract address).
- The operator (EOA) only solves challenges and forwards coordinator-provided mining calldata to the mining contract so credits accrue on the pool address.
- After epoch end, anyone can permissionlessly call `claimRewards(epoch)` to claim BOTCOIN into the pool.
- Depositors claim rewards via on-chain accounting based on credit production time using `claimUser([...], to)`, without trusting the operator for distribution.
- Principal can be withdrawn by depositors after lock expiry; the operator can never block withdrawals.

## Contract Overview

Core contract: `src/SharedMiningPoolContract.sol`

- Deposit mode (immutable at deployment):
  - `Immediate`: a deposit in epoch N immediately affects tier/allocation in epoch N; withdrawal is allowed after epoch N ends.
  - `NextEpochCutoff`: a deposit in epoch N does not affect tier/allocation in epoch N; it becomes active only after rollover to epoch N+1.
- Credits accounting semantics: every `submitReceiptToMining(miningCalldata)` call reads `credits(epoch, this)` delta `Δcredits` and allocates only that delta by current active shares (index-debt model).
- Reward accounting semantics: `claimRewards(epoch)` claims BOTCOIN for the epoch and stores net amount after immutable fee; `claimUser` pays users according to their per-epoch credits share.

Cutoff-mode escrow vault: `src/EscrowVault.sol` isolates pending deposits from active principal so pending funds do not pollute mining tier.

## Deployment Parameters (all immutable)

Constructor parameters:

- `miningContract_`: Base mining contract address (fill mainnet address in production).
- `operator_`: operator EOA (single trust point: solving and forwarding receipts).
- `feeRecipient_`: immutable fee recipient.
- `feeBps_`: immutable fee in BPS (`<= 2000` in current contract).
- `depositMode_`: `Immediate` or `NextEpochCutoff`.
- `receiptSubmitSelector_`: allowlisted selector extracted from the first 4 bytes of coordinator mining calldata.
- `maxEpochsPerClaim_`: max epoch count processed by one `claimUser` call (gas bound).

Values read and fixed during construction:

- `botcoinToken`: from `mining.botcoinToken()`.

## External API (MVP)

- `isValidSignature(bytes32 digest, bytes signature) -> bytes4`: strict EIP-1271 (65-byte only, low-s, never reverts).
- `deposit(uint256 amount)`
- `withdraw(uint256 amount, address to)`: strict epoch lock semantics.
- `submitReceiptToMining(bytes miningCalldata)`: `onlyOperator` + selector allowlist + `Δcredits > 0`.
- `claimRewards(uint64 epoch)`: permissionless (epoch must be ended).
- `claimUser(uint64[] epochs, address to)`: user self-serve epoch claims.
- `checkpointEpoch()`: permissionless rollover in Cutoff mode; no-op in Immediate mode.

View helpers:

- `getEpochState(uint64 epoch)`
- `getUserEpochState(address user, uint64 epoch)`
- `getUserPrincipalState(address user)`
- `userSharesAtEpoch(address user, uint64 epoch)`

## Security Boundaries

### 1) EIP-1271 digest handling (no re-hash)

Coordinator passes an EIP-191 personal-sign digest (`ethers.hashMessage(message)`) to `isValidSignature(digest, signature)`.

The pool must validate that digest directly:

- Do not hash raw message bytes again.
- Do not hash the digest again.

### 2) `submitReceiptToMining` calldata abuse prevention

`submitReceiptToMining` enforces:

- `onlyOperator`
- calldata selector must equal immutable `receiptSubmitSelector`
- pre/post read of `credits(currentEpoch, address(this))` with strict `Δcredits > 0`

This prevents turning the pool into a generic mining-contract proxy.

### 3) Cutoff-mode escrow requirement

In Cutoff mode, pending deposits must be held in `EscrowVault` instead of remaining on pool balance. Otherwise:

- mining tier based on `BOTCOIN.balanceOf(msg.sender)` would be polluted by pending funds
- late-epoch deposit tier gaming/arbitrage becomes possible

## Run Tests and Capture Logs

This project uses Foundry (`forge`). 

### Bash

Format:

```bash
cd shared_mining_pool_contract && forge fmt
```

Run full suite (unit + fuzz + invariant):

```bash
cd shared_mining_pool_contract && forge test -vvv
```

Write terminal output to a single log file:

```bash
cd shared_mining_pool_contract && forge test -vvv 2>&1 | tee ./shared_mining_pool_contract.log
```

## Deployment and End-to-End Boundaries (coordinator / Bankr)

- Miner can be a contract address (the pool contract).
- Operator EOA still signs coordinator nonce messages with personal-sign.
- `/v1/submit` returns calldata intended for direct mining-contract invocation.
- Operator must pass that calldata into `pool.submitReceiptToMining(miningCalldata)` so mining sees `msg.sender == pool`.




