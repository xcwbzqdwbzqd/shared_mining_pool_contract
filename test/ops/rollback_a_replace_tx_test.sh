#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

output="$(
  bash "$ROOT_DIR/tools/release/rollback_a_replace_tx.sh" \
    --dry-run \
    --rpc-url https://mainnet.base.org \
    --from 0x000000000000000000000000000000000000dEaD \
    --nonce 7 \
    --gas-price 2gwei
)"

echo "$output" | rg "cast send" >/dev/null
echo "$output" | rg -- "--nonce 7" >/dev/null
echo "$output" | rg "https://mainnet.base.org" >/dev/null

