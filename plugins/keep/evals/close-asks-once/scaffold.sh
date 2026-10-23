#!/usr/bin/env bash
set -euo pipefail
bash "$(dirname "$0")/../_fixture/sandbox.sh"
# Two open items, so one list for both can be told apart from one question per item.
awk '{ print } /^- \[ \] Q-1:/ { print "- [ ] Q-2: are codes case-sensitive? — acceptance: a decision in DECISIONS.md" }' .keep/demo/research/STATE.md > .keep/demo/research/STATE.tmp
mv .keep/demo/research/STATE.tmp .keep/demo/research/STATE.md
git -C .keep commit -qam "Add Q-2"
