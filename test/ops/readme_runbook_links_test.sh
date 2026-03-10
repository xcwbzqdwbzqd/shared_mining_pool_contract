#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

rg -n "Base Sepolia" "$ROOT_DIR/README.md" >/dev/null
rg -n "Base mainnet" "$ROOT_DIR/README.md" >/dev/null
rg -n "Rollback A" "$ROOT_DIR/README.md" >/dev/null
rg -n "Rollback B" "$ROOT_DIR/README.md" >/dev/null
rg -n "docs/release" "$ROOT_DIR/README.md" >/dev/null

