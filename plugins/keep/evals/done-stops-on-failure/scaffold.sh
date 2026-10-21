#!/usr/bin/env bash
set -euo pipefail
bash "$(dirname "$0")/../_fixture/sandbox.sh"
f=.keep/demo/tickets/STATE.md
sed 's/^- Ticket: none \[verified\]$/- Ticket: T-1 [assumed] applyDiscount takes the percentage off/' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
git -C .keep commit -q -am "T-1 in progress"
