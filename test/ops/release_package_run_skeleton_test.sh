#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_PACKAGE="$ROOT_DIR/docs/release/runs/2026-03-09-base-mainnet-release/base-mainnet-release-package.md"

rg -n "^# Base Mainnet Release Package$" "$RUN_PACKAGE" >/dev/null
rg -n "<OPERATOR>" "$RUN_PACKAGE" >/dev/null
rg -n "<RPC_URL>" "$RUN_PACKAGE" >/dev/null
rg -n "cast chain-id --rpc-url" "$RUN_PACKAGE" >/dev/null
rg -n "cast wallet address --account" "$RUN_PACKAGE" >/dev/null
rg -n "cast receipt" "$RUN_PACKAGE" >/dev/null
rg -n "<RAW_STDOUT_CHAIN_ID>" "$RUN_PACKAGE" >/dev/null
rg -n "<RAW_STDOUT_WALLET_ADDRESS>" "$RUN_PACKAGE" >/dev/null
rg -n "<RAW_STDOUT_RECEIPT>" "$RUN_PACKAGE" >/dev/null
