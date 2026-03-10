#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ABI_JSON="$(cd "$ROOT_DIR" && forge inspect SharedMiningPoolV2 abi --json)"
ABI_NAMES="$(
    ABI_JSON_INPUT="$ABI_JSON" python3 - <<'PY'
import json
import os

abi = json.loads(os.environ["ABI_JSON_INPUT"])
for item in abi:
    name = item.get("name")
    if name:
        print(name)
PY
)"

printf '%s\n' "$ABI_NAMES" | rg -x "submitToMining" >/dev/null
printf '%s\n' "$ABI_NAMES" | rg -x "triggerClaim" >/dev/null
printf '%s\n' "$ABI_NAMES" | rg -x "triggerBonusClaim" >/dev/null

if printf '%s\n' "$ABI_NAMES" | rg -x "submitReceiptToMining" >/dev/null; then
    exit 1
fi
if printf '%s\n' "$ABI_NAMES" | rg -x "claimRewards" >/dev/null; then
    exit 1
fi
if printf '%s\n' "$ABI_NAMES" | rg -x "claimBonusRewards" >/dev/null; then
    exit 1
fi
