#!/usr/bin/env bash
# Runs the keep hooks against simulated hook inputs in a scratch project. Usage: bash tests/hooks.test.sh
set -uo pipefail
H="$(cd "$(dirname "$0")/../plugins/keep" && pwd)"
R=$(mktemp -d "${TMPDIR:-/tmp}/keep-test.XXXXXX")
trap 'rm -rf "$R"' EXIT
export CLAUDE_PROJECT_DIR="$R"
unset KEEP_FOLDER COMPACT_LIMIT
K="$R/.keep"
st="$K/.state"
pass=0; fail=0
ok() { if eval "$2"; then pass=$((pass + 1)); echo "PASS $1"; else fail=$((fail + 1)); echo "FAIL $1"; fi; }
hook() { printf '%s' "$2" | "$H/hooks/$1.sh"; }
q() { git -C "$1" "${@:2}" >/dev/null 2>&1; }

# A project with two repos and two features: "shop" (two tracks) and "solo" (one track).
for r in api web; do
  mkdir -p "$R/$r"; q "$R/$r" init -b main; q "$R/$r" -c user.name=t -c user.email=t@example.com commit --allow-empty -m "start $r"
done
mkdir -p "$K/shop/tickets" "$K/shop/research" "$K/solo/main"
printf '# Feature: shop\n\n**Repos:** api, web\n\n**Read on start:**\n- DIGEST.md\n' > "$K/shop/FEATURE.md"
printf '# Feature: solo\n' > "$K/solo/FEATURE.md"
printf '# Track: shop/tickets\n**Goal:** ship tickets\n' > "$K/shop/tickets/CONTEXT.md"
state() { printf '# State: %s\n\n## Inbox\n\n## Current\n<!-- comment -->\n- Ticket: %s\n\n## Next step\n- %s\n\n## Done log\n' "$1" "$2" "$3"; }
state shop/tickets "T-7 checkout fix" "edit api/cart.js applyDiscount" > "$K/shop/tickets/STATE.md"
state shop/research "pricing question" "read the vendor docs" > "$K/shop/research/STATE.md"
state solo/main "none" "none" > "$K/solo/main/STATE.md"

echo "--- no keep folder"
E=$(mktemp -d "${TMPDIR:-/tmp}/keep-empty.XXXXXX")
for h in bind load track stop; do
  out=$(printf '{"session_id":"s1","prompt":"/keep:start shop/tickets","source":"startup"}' | CLAUDE_PROJECT_DIR="$E" "$H/hooks/$h.sh"; echo "exit=$?")
  ok "$h is silent without a keep folder" '[ "$out" = "exit=0" ] && [ ! -e "$E/.keep" ]'
done
rm -rf "$E"

echo "--- binding"
out=$(hook load '{"session_id":"s1","source":"startup"}')
ok "unbound chat lists tracks with their current work" '[[ "$out" == *"No keep track is bound"* && "$out" == *"shop/tickets: Ticket: T-7 checkout fix"* && "$out" == *"solo/main"* ]]'
ok "the state folder ignores itself in git" '[ "$(cat "$st/.gitignore")" = "*" ]'
out=$(hook bind '{"session_id":"s1","prompt":"/keep:start shop/tickets"}')
ok "bind names the chat after the track" '[ "$(jq -r .hookSpecificOutput.sessionTitle <<<"$out")" = shop/tickets ]'
ok "bind records the binding" '[ "$(cat "$st/track-s1")" = shop/tickets ]'
out=$(hook bind '{"session_id":"s2","prompt":"/start shop/research"}')
ok "the unprefixed form binds too" '[ "$(cat "$st/track-s2" 2>/dev/null)" = shop/research ]'
out=$(hook bind '{"session_id":"s3","prompt":"/keep:start solo"}')
ok "a feature with one track binds to it" '[ "$(cat "$st/track-s3" 2>/dev/null)" = solo/main ]'
for p in "/keep:start shop" "/keep:start shop/nope" "/keep:start ../shop/tickets" "/keep:start .state/x" "hello /keep:start shop/tickets" "/keep:startshop/tickets"; do
  out=$(hook bind "{\"session_id\":\"s4\",\"prompt\":\"$p\"}")
  ok "no binding for: $p" '[ -z "$out" ] && [ ! -f "$st/track-s4" ]'
done

echo "--- loading"
out=$(hook load '{"session_id":"s1","source":"resume"}')
ok "bound chat loads feature, context and state" '[[ "$out" == *"Active track: shop/tickets"* && "$out" == *"**Repos:** api, web"* && "$out" == *"ship tickets"* && "$out" == *"T-7 checkout fix"* ]]'
ok "without a stamp it says nothing was checked against git" '[[ "$out" == *"No git stamp yet"* ]]'
ok "no compaction notes on resume" '[[ "$out" != *compacted* ]]'

echo "--- tracking and the Stop gate"
edit() { hook track "{\"session_id\":\"$1\",\"tool_name\":\"$2\",\"tool_input\":{\"file_path\":\"$3\"}}"; }
stop() { hook stop "{\"session_id\":\"$1\",\"stop_hook_active\":$2}"; }
out=$(stop s1 false);                                  ok "stop passes while clean" '[ -z "$out" ]'
edit s1 Edit "$K/shop/FEATURE.md";                     ok "editing keep files stays clean" '[ ! -f "$st/dirty-s1" ]'
edit s1 Edit "$K/shop/research/STATE.md";              ok "editing another track's state stays clean" '[ ! -f "$st/dirty-s1" ]'
edit s1 Edit "$R/.claude/settings.json";               ok "editing .claude stays clean" '[ ! -f "$st/dirty-s1" ]'
edit s1 Edit "$R/api/cart.js";                         ok "a project edit marks the chat dirty" '[ -f "$st/dirty-s1" ]'
out=$(stop s1 false)
ok "stop blocks while dirty, naming the state file" '[ "$(jq -r .decision <<<"$out")" = block ] && [[ "$(jq -r .reason <<<"$out")" == *".keep/shop/tickets/STATE.md"* ]]'
out=$(stop s1 true);                                   ok "stop_hook_active lets it stop" '[ -z "$out" ]'
edit s1 Edit "$K/shop/tickets/STATE.md";               ok "updating the track's state clears it" '[ ! -f "$st/dirty-s1" ]'
out=$(stop s1 false);                                  ok "stop passes after the update" '[ -z "$out" ]'
ok "the update stamps both repos" '[ "$(cut -f1 "$K/shop/tickets/.stamp" | tr "\n" " ")" = "api web " ] && [ "$(cut -f2 "$K/shop/tickets/.stamp" | head -1)" = "$(git -C "$R/api" rev-parse HEAD)" ]'
for t in WebFetch WebSearch Agent; do
  hook track "{\"session_id\":\"s1\",\"tool_name\":\"$t\",\"tool_input\":{}}"
  ok "$t marks the chat dirty" '[ -f "$st/dirty-s1" ]'; rm -f "$st/dirty-s1"
done
m=$(jq -r '.hooks.PostToolUse[0].matcher' "$H/hooks/hooks.json")
ok "the matcher passes edits and research, not Read or Bash" '[[ "Edit" =~ ^($m)$ && "Agent" =~ ^($m)$ && ! "Read" =~ ^($m)$ && ! "Bash" =~ ^($m)$ ]]'
edit s9 Edit "$R/api/cart.js";                         ok "an unbound chat is never tracked" '[ ! -f "$st/dirty-s9" ]'
out=$(stop s9 false);                                  ok "an unbound chat is never blocked" '[ -z "$out" ]'

echo "--- freshness"
q "$R/api" -c user.name=t -c user.email=t@example.com commit --allow-empty -m "fix cart totals"
q "$R/web" checkout -b redesign
touch "$R/web/new.txt"
out=$(hook load '{"session_id":"s1","source":"resume"}')
ok "a new commit is reported with its subject" '[[ "$out" == *"api (main): 1 new commit(s)"* && "$out" == *"fix cart totals"* ]]'
ok "a branch change and new files are reported" '[[ "$out" == *"branch changed from main to redesign"* && "$out" == *"1 uncommitted file(s), was 0"* ]]'
ok "it asks to recheck before acting" '[[ "$out" == *"Recheck files before acting"* ]]'

echo "--- compaction and /clear"
out=$(hook load '{"session_id":"s1","source":"compact"}')
ok "the first compaction is counted" '[[ "$out" == *"compacted 1 time"* && "$out" == *"Read on start"* && "$out" != *"/keep:save"* ]]'
out=$(hook load '{"session_id":"s1","source":"compact"}')
ok "the second asks for /keep:save and a fresh chat" '[[ "$out" == *"compacted 2 time"* && "$out" == *"/keep:save"* && "$out" == *"/keep:start shop/tickets"* ]]'
echo bogus > "$st/compactions-s1"
out=$(hook load '{"session_id":"s1","source":"compact"}')
ok "a corrupt counter restarts at 1" '[[ "$out" == *"compacted 1 time"* ]]'
out=$(hook load '{"session_id":"s1","source":"clear"}')
ok "clear resets the count and keeps the binding" '[ ! -f "$st/compactions-s1" ] && [[ "$out" == *"Active track: shop/tickets"* ]]'
out=$(hook load '{"session_id":"s5","source":"clear","session_title":"shop/research"}')
ok "a new session id rebinds from the chat title" '[ "$(cat "$st/track-s5" 2>/dev/null)" = shop/research ] && [[ "$out" == *"Active track: shop/research"* ]]'
for t in "Fix the bug" "../shop/tickets" "shop/tickets/x" ".state/x"; do
  out=$(hook load "{\"session_id\":\"s6\",\"source\":\"resume\",\"session_title\":\"$t\"}")
  ok "no rebinding from the title: $t" '[ ! -f "$st/track-s6" ] && [[ "$out" == *"No keep track is bound"* ]]'
done

echo "--- size limits"
{ state shop/tickets "T-8 big" "edit web/app.js render"; for i in $(seq 1 120); do echo "- 2026-10-$((i % 28 + 1)) · T-$i · abc$i · tests passed, with a long note to fill space"; done; printf '\n## Gotchas\n- small gotcha\n'; } > "$K/shop/tickets/STATE.md"
out=$(hook load '{"session_id":"s1","source":"resume"}')
n=$(printf '%s' "$out" | wc -m | tr -d ' ')
ok "a big state keeps Inbox, Current and Next step" '[[ "$out" == *"## Inbox"* && "$out" == *"T-8 big"* && "$out" == *"edit web/app.js render"* ]]'
ok "the sections left out are named" '[[ "$out" == *"Not loaded, to stay under the hook output limit: Done log"* ]]'
ok "sections that fit still load" '[[ "$out" == *"small gotcha"* ]]'
ok "the output stays under 10,000 characters ($n)" '[ "$n" -lt 10000 ]'
{ printf '# State: shop/tickets\n\n## Current\n'; for i in $(seq 1 400); do echo "- [assumed] a very long current line number $i that keeps going"; done; } > "$K/shop/tickets/STATE.md"
out=$(hook load '{"session_id":"s1","source":"resume"}')
n=$(printf '%s' "$out" | wc -m | tr -d ' ')
ok "even an oversized Current is cut under 10,000 characters ($n)" '[ "$n" -lt 10000 ] && [[ "$out" == *"[Cut to stay under the hook output limit"* ]]'

echo "--- bad input"
for h in bind load track stop; do
  out=$(printf 'not json' | "$H/hooks/$h.sh"; echo "exit=$?")
  ok "$h ignores bad input" '[ "$out" = "exit=0" ]'
done

echo "--- helper scripts"
out=$(bash "$H/scripts/status.sh" "$R")
ok "status lists every track" '[ "$(printf "%s\n" "$out" | wc -l | tr -d " ")" = 3 ]'
out=$(KEEP_FOLDER=elsewhere bash "$H/scripts/status.sh" "$R")
ok "KEEP_FOLDER points at another folder" '[[ "$out" == *"No keep folder at $R/elsewhere"* ]]'
out=$(bash "$H/scripts/freshness.sh" "$R" ".keep/shop/research")
ok "freshness says when there's no stamp" '[[ "$out" == *"No git stamp yet"* ]]'

echo "---"
echo "passed $pass, failed $fail"
[ "$fail" = 0 ]
