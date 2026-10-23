#!/usr/bin/env bash
set -euo pipefail
bash "$(dirname "$0")/../_fixture/sandbox.sh"
dup='- 2026-10-19 · T-0 · abc1234 · set up the discount module skeleton and its first test, all green'
printf '\n## Done log (older)\n%s\n' "$dup" >> .keep/demo/tickets/NOTES.md
f=.keep/demo/tickets/STATE.md
awk -v d="$dup" '{ print } /^## Done log$/ { print d }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
git -C .keep commit -q -am "Add a duplicated Done-log line"
