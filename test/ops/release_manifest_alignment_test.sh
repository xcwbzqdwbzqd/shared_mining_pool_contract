#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="$ROOT_DIR/docs/release/01-manifest-template.md"

rg -n "^## Locked Protocol Constants$" "$MANIFEST" >/dev/null
rg -n "^## Release Inputs$" "$MANIFEST" >/dev/null
rg -n "^## Derived Runtime Values$" "$MANIFEST" >/dev/null
rg -n "^## Observed Validation Evidence$" "$MANIFEST" >/dev/null
rg -n "^## Operational Decisions$" "$MANIFEST" >/dev/null
