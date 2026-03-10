#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

rg -n "chain id|git commit|feeBps|maxEpochsPerClaim|receiptSubmitSelector|rollback A|rollback B" "$ROOT_DIR/docs/release/01-manifest-template.md" >/dev/null
rg -n "tx_hash,nonce,gas,block,status,note" "$ROOT_DIR/docs/release/03-transactions-template.csv" >/dev/null

