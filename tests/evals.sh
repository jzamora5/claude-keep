#!/usr/bin/env bash
# Runs keep's eval suite (plugins/keep/evals/) in real headless sessions. Usage: bash tests/evals.sh [max USD]
# One run per case and no no-plugin baseline keep the cost low: the cases test keep's own commands, which a
# session without keep can't run anyway. The cap is on the runner's list-price estimate (default 4).
set -euo pipefail
cd "$(dirname "$0")/../plugins/keep"
exec claude plugin eval . --runs 1 --ablation none --scaffold --trust-plugin --no-publish -j 2 \
  --max-cost-usd "${1:-4}" --allow-tools Edit Write Bash
