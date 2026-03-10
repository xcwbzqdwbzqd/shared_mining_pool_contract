#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

output="$(bash "$ROOT_DIR/tools/release/rollback_b_redeploy.sh" --dry-run)"

echo "$output" | rg "forge create src/SharedMiningPoolV2.sol:SharedMiningPoolV2" >/dev/null
echo "$output" | rg "0xf9b5aac1" >/dev/null
echo "$output" | rg " 500 " >/dev/null
echo "$output" | rg " 20" >/dev/null

