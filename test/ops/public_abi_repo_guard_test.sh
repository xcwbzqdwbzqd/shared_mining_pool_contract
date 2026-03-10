#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OLD_PUBLIC_NAME_PATTERN='\b(submitReceiptToMining|claimRewards|claimBonusRewards|claimUser|withdrawPrincipal|finalizeWithdraw|stakePrincipal|checkpointEpoch)\b'

active_hits="$(
    cd "$ROOT_DIR" && rg -n "$OLD_PUBLIC_NAME_PATTERN" \
        src test script README.md AGENTS.md docs/release \
        --glob '!test/ops/public_abi_operator_reward_cutover_test.sh' \
        --glob '!test/ops/public_abi_lifecycle_user_cutover_test.sh' \
        --glob '!test/ops/public_abi_repo_guard_test.sh' \
        --glob '!docs/audit/**' \
        --glob '!docs/plans/2026-02-28-botcoin-pool-v2-design.md' \
        --glob '!docs/plans/2026-02-28-botcoin-pool-v2-implementation-plan.md' \
        --glob '!docs/plans/2026-03-01-base-mainnet-from-zero-deployment-design.md' \
        --glob '!docs/plans/2026-03-01-v2-hard-cutover-design.md' \
        --glob '!docs/plans/2026-03-10-shared-mining-pool-v2-abi-hard-cutover-design.md' \
        --glob '!docs/plans/2026-03-10-shared-mining-pool-v2-abi-hard-cutover-implementation-plan.md' || true
)"

if [[ -n "$active_hits" ]]; then
    printf '%s\n' "$active_hits"
    exit 1
fi

historical_with_old_names="$(
    cd "$ROOT_DIR" && rg -l "$OLD_PUBLIC_NAME_PATTERN" \
        docs/audit \
        docs/plans/2026-02-28-botcoin-pool-v2-design.md \
        docs/plans/2026-02-28-botcoin-pool-v2-implementation-plan.md \
        docs/plans/2026-03-01-base-mainnet-from-zero-deployment-design.md \
        docs/plans/2026-03-01-v2-hard-cutover-design.md \
        docs/plans/2026-03-10-shared-mining-pool-v2-abi-hard-cutover-design.md \
        docs/plans/2026-03-10-shared-mining-pool-v2-abi-hard-cutover-implementation-plan.md || true
)"

if [[ -n "$historical_with_old_names" ]]; then
    while IFS= read -r path; do
        [[ -z "$path" ]] && continue
        rg -n "pre-cutover ABI" "$ROOT_DIR/$path" >/dev/null
    done <<< "$historical_with_old_names"
fi
