#!/usr/bin/env bash
set -euo pipefail
bash "$(dirname "$0")/../_fixture/sandbox.sh"
# Two open items, so one list for both can be told apart from one question per item.
awk '{ print } /^- \[ \] Q-1:/ { print "- [ ] Q-2: are codes case-sensitive? — acceptance: a decision in DECISIONS.md" }' .trackside/demo/research/STATE.md > .trackside/demo/research/STATE.tmp
mv .trackside/demo/research/STATE.tmp .trackside/demo/research/STATE.md
git -C .trackside commit -qam "Add Q-2"
