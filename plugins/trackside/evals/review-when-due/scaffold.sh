#!/usr/bin/env bash
set -euo pipefail
bash "$(dirname "$0")/../_fixture/sandbox.sh"
for i in $(seq 1 220); do echo "- reference note $i: a line of background about the discount feature and its history"; done >> .trackside/demo/tickets/NOTES.md
git -C .trackside commit -q -am "Grow the notes past 10 KB"
