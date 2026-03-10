#!/usr/bin/env bash
set -euo pipefail

cd /home/devuser/ARDID/BOTCOIN/shared_mining_pool_contract/shared_mining_pool_contract

test -f docs/audit/2026-03-11-ipfs-line-by-line-requirement-ledger.md
test -f docs/audit/2026-03-11-ipfs-line-by-line-audit-report.md

rg -q '^# BOTCOIN IPFS Line-by-Line Requirement Ledger$' docs/audit/2026-03-11-ipfs-line-by-line-requirement-ledger.md
rg -q '^# BOTCOIN IPFS Line-by-Line Audit Report$' docs/audit/2026-03-11-ipfs-line-by-line-audit-report.md

test -f docs/audit/evidence/2026-03-11/baseline_build.txt
test -f docs/audit/evidence/2026-03-11/baseline_test.txt
test -f docs/audit/evidence/2026-03-11/shared_pool_abi.txt
test -f docs/audit/evidence/2026-03-11/active_repo_grep.txt
test -f docs/audit/evidence/2026-03-11/external_contracts.txt
