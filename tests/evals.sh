#!/usr/bin/env bash
# Runs trackside's eval suite (plugins/trackside/evals/) in real headless sessions. Usage: bash tests/evals.sh [max
# USD] One run per case and no no-plugin baseline keep the cost low: the cases test trackside's own commands, which
# a session without trackside can't run anyway. The cap is on the runner's list-price estimate (default 4).
set -euo pipefail
cd "$(dirname "$0")/../plugins/trackside"
exec claude plugin eval . --runs 1 --ablation none --scaffold --trust-plugin --no-publish -j 2 \
  --max-cost-usd "${1:-4}" --allow-tools Edit Write Bash
