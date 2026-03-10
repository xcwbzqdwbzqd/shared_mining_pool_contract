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

printf '%s\n' "$ABI_NAMES" | rg -x "claimMyShare" >/dev/null
printf '%s\n' "$ABI_NAMES" | rg -x "completeWithdraw" >/dev/null
printf '%s\n' "$ABI_NAMES" | rg -x "stakeAvailablePrincipal" >/dev/null
printf '%s\n' "$ABI_NAMES" | rg -x "claimMyRewards" >/dev/null
printf '%s\n' "$ABI_NAMES" | rg -x "processEpochCheckpoint" >/dev/null

if printf '%s\n' "$ABI_NAMES" | rg -x "withdrawPrincipal" >/dev/null; then
    exit 1
fi
if printf '%s\n' "$ABI_NAMES" | rg -x "finalizeWithdraw" >/dev/null; then
    exit 1
fi
if printf '%s\n' "$ABI_NAMES" | rg -x "stakePrincipal" >/dev/null; then
    exit 1
fi
if printf '%s\n' "$ABI_NAMES" | rg -x "claimUser" >/dev/null; then
    exit 1
fi
if printf '%s\n' "$ABI_NAMES" | rg -x "checkpointEpoch" >/dev/null; then
    exit 1
fi
