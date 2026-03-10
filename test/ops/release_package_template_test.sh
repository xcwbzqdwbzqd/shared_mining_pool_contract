#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMPLATE="$ROOT_DIR/docs/release/05-base-mainnet-release-package-template.md"

rg -n "^# Base Mainnet Release Package Template$" "$TEMPLATE" >/dev/null
rg -n "^## 1\\. Direct Conclusion$" "$TEMPLATE" >/dev/null
rg -n "^## 14\\. B1 Broadcast$" "$TEMPLATE" >/dev/null
rg -n "^## 18\\. Rollback A: Pending Tx Cancel / Replace$" "$TEMPLATE" >/dev/null
rg -n "cast wallet address" "$TEMPLATE" >/dev/null
rg -n "forge create src/SharedMiningPoolV2.sol:SharedMiningPoolV2" "$TEMPLATE" >/dev/null
