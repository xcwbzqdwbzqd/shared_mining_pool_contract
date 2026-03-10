#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

rg -n "Base mainnet release package template" "$ROOT_DIR/README.md" >/dev/null
rg -n "docs/release/05-base-mainnet-release-package-template.md" "$ROOT_DIR/README.md" >/dev/null
rg -n "docs/release/runs/" "$ROOT_DIR/README.md" >/dev/null
