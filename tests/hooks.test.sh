#!/usr/bin/env bash
# Runs the keep hooks against simulated hook inputs in a scratch project. Usage: bash tests/hooks.test.sh
set -uo pipefail
H="$(cd "$(dirname "$0")/../plugins/keep" && pwd)"
R=$(mktemp -d "${TMPDIR:-/tmp}/keep-test.XXXXXX")
trap 'rm -rf "$R"' EXIT
export CLAUDE_PROJECT_DIR="$R"
unset COMPACT_LIMIT KEEP_IDLE_DAYS KEEP_STATE_DAYS
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
ok "and asks the agent to suggest the matching track without binding it" '[[ "$out" == *"In your first reply"* && "$out" == *"Only suggest"* ]]'
ok "the state folder ignores itself in git" '[ "$(cat "$st/.gitignore")" = "*" ]'
out=$(hook bind '{"session_id":"s1","prompt":"/keep:start shop/tickets"}')
ok "bind names the chat after the track" '[ "$(jq -r .hookSpecificOutput.sessionTitle <<<"$out")" = shop/tickets ]'
ok "bind records the binding" '[ "$(cat "$st/track-s1")" = shop/tickets ]'
out=$(hook bind '{"session_id":"s2","prompt":"/start shop/research"}')
ok "the unprefixed form binds too" '[ "$(cat "$st/track-s2" 2>/dev/null)" = shop/research ]'
out=$(hook bind '{"session_id":"s3","prompt":"/keep:start solo"}')
ok "a feature with one track binds to it" '[ "$(cat "$st/track-s3" 2>/dev/null)" = solo/main ]'
out=$(hook bind '{"session_id":"r1","prompt":"/keep:start research"}')
ok "a track name used by one feature binds to that track" '[ "$(cat "$st/track-r1" 2>/dev/null)" = shop/research ] && [ "$(jq -r .hookSpecificOutput.sessionTitle <<<"$out")" = shop/research ]'
hook bind '{"session_id":"r2","prompt":"/keep:start main"}' >/dev/null
ok "so does the only track of another feature" '[ "$(cat "$st/track-r2" 2>/dev/null)" = solo/main ]'
mkdir -p "$K/other/tickets" && cp "$K/solo/main/STATE.md" "$K/other/tickets/STATE.md"
out=$(hook bind '{"session_id":"r3","prompt":"/keep:start tickets"}')
ok "a track name used by two features doesn't bind" '[ -z "$out" ] && [ ! -f "$st/track-r3" ]'
out=$(bash "$H/scripts/status.sh" "$R")
ok "the listing then falls back to full names for those tracks" '[[ "$out" == *"shop/tickets: Ticket: T-7 checkout fix (start: /keep:start shop/tickets)"* && "$out" == *"other/tickets: Ticket: none (start: /keep:start other)"* ]]'
rm -rf "$K/other"; rm -f "$st/track-r1" "$st/track-r2"
out=$(hook bind '{"session_id":"s8","prompt":"/keep:start shop/tickets and continue"}')
ok "words after the track are fine" '[ "$(cat "$st/track-s8" 2>/dev/null)" = shop/tickets ]'; rm -f "$st/track-s8"
for p in "/keep:start shop" "/keep:start shop/nope" "/keep:start ../shop/tickets" "/keep:start .state/x" "hello /keep:start shop/tickets" "/keep:startshop/tickets" "/keep:start shop/tickets/extra"; do
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
edit s1 Edit "$R/.claude/settings.json";               ok "editing the project's .claude stays clean" '[ ! -f "$st/dirty-s1" ]'
edit s1 Write "$HOME/.claude/projects/p/memory/MEMORY.md"; ok "writing Claude's own memory or plans stays clean" '[ ! -f "$st/dirty-s1" ]'
edit s1 Edit "$R/.claude/worktrees/w1/api/cart.js";    ok "an edit in a Claude Code worktree marks the chat dirty" '[ -f "$st/dirty-s1" ]'; rm -f "$st/dirty-s1"
edit s1 Edit "$R/api/.claude/notes.md";                ok "a repo's own .claude folder counts as project files" '[ -f "$st/dirty-s1" ]'; rm -f "$st/dirty-s1"
edit s1 Edit "$R/api/cart.js";                         ok "a project edit marks the chat dirty" '[ -f "$st/dirty-s1" ]'
out=$(stop s1 false)
ok "stop sends Stop hook feedback naming the state file" '[ "$(jq -r .hookSpecificOutput.hookEventName <<<"$out")" = Stop ] && [[ "$(jq -r .hookSpecificOutput.additionalContext <<<"$out")" == *".keep/shop/tickets/STATE.md"* ]] && [ "$(jq -r ".decision // empty" <<<"$out")" = "" ]'
out=$(stop s1 true);                                   ok "stop_hook_active lets it stop" '[ -z "$out" ]'
edit s1 Edit "$K/shop/tickets/STATE.md";               ok "updating the track's state clears it" '[ ! -f "$st/dirty-s1" ]'
out=$(stop s1 false);                                  ok "stop passes after the update" '[ -z "$out" ]'
stamp="$st/stamp-shop@tickets"
ok "the update stamps both repos, in .state" '[ "$(cut -f1 "$stamp" | tr "\n" " ")" = "api web " ] && [ "$(cut -f2 "$stamp" | head -1)" = "$(git -C "$R/api" rev-parse HEAD)" ] && [ ! -e "$K/shop/tickets/.stamp" ]'
for t in WebFetch WebSearch; do
  hook track "{\"session_id\":\"s1\",\"tool_name\":\"$t\",\"tool_input\":{}}"
  ok "$t marks the chat dirty" '[ -f "$st/dirty-s1" ]'; rm -f "$st/dirty-s1"
done
hook track '{"session_id":"s1","tool_name":"Agent","tool_input":{"subagent_type":"Explore"}}'
ok "another subagent marks the chat dirty" '[ -f "$st/dirty-s1" ]'; rm -f "$st/dirty-s1"
hook track '{"session_id":"s1","tool_name":"Agent","tool_input":{"subagent_type":"keep:doc-expert"}}'
ok "asking keep's doc-expert doesn't" '[ ! -f "$st/dirty-s1" ]'
hook track '{"session_id":"s1","tool_name":"Agent","tool_input":{"subagent_type":"doc-expert"}}'
ok "nor does the unprefixed name" '[ ! -f "$st/dirty-s1" ]'
hook track '{"session_id":"s1","tool_name":"Agent","tool_input":{"subagent_type":"my-team:doc-expert"}}'
ok "another plugin's doc-expert still counts" '[ -f "$st/dirty-s1" ]'; rm -f "$st/dirty-s1"
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
ok "a branch change and new files are reported" '[[ "$out" == *"branch changed from main to redesign"* && "$out" == *"uncommitted changes differ: 1 file(s) now, 0 then"* ]]'
ok "it asks to recheck before acting" '[[ "$out" == *"Recheck files before acting"* ]]'
q "$R/web" checkout main
rm -f "$R/web/new.txt"
printf 'one\n' > "$R/api/notes.txt"
edit s1 Edit "$K/shop/tickets/STATE.md"
printf 'two\n' > "$R/api/notes.txt"
touch -t "$(date -v+2M +%Y%m%d%H%M 2>/dev/null || date -d '2 minutes' +%Y%m%d%H%M)" "$R/api/notes.txt"
q "$R/api" reset --hard HEAD~1
out=$(bash "$H/scripts/freshness.sh" "$R" shop/tickets)
ok "a reset to an older commit is reported" '[[ "$out" == *"api (main): moved back 1 commit(s)"* ]]'
ok "rewriting a file that was already uncommitted is reported" '[[ "$out" == *"api (main): moved back 1 commit(s); uncommitted changes differ: 1 file(s) now, 1 then"* ]]'
ok "an unchanged repo still says so" '[[ "$out" == *"web (main): no changes"* ]]'

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
n=$(printf '%s' "$out" | wc -c | tr -d ' ')
ok "a big state keeps Inbox, Current and Next step" '[[ "$out" == *"## Inbox"* && "$out" == *"T-8 big"* && "$out" == *"edit web/app.js render"* ]]'
ok "the sections left out are named" '[[ "$out" == *"Not loaded, to stay under the hook output limit: Done log"* ]]'
ok "sections that fit still load" '[[ "$out" == *"small gotcha"* ]]'
ok "the output stays under 10,000 bytes ($n)" '[ "$n" -lt 10000 ]'
ok "the output is valid UTF-8" 'printf "%s" "$out" | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1'
{ printf '# State: shop/tickets\n\n## Current\n'; for i in $(seq 1 400); do echo "- [assumed] a very long current line number $i that keeps going — with · marks"; done; } > "$K/shop/tickets/STATE.md"
out=$(hook load '{"session_id":"s1","source":"resume"}')
n=$(printf '%s' "$out" | wc -c | tr -d ' ')
ok "even an oversized Current is cut under 10,000 bytes ($n)" '[ "$n" -lt 10000 ] && [[ "$out" == *"[Cut to stay under the hook output limit"* ]]'
ok "the cut falls at a line end, so no character is split" 'printf "%s" "$out" | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1'

echo "--- index, idle tracks and housekeeping"
ago() { date -v-"$1"d +%Y%m%d%H%M 2>/dev/null || date -d "$1 days ago" +%Y%m%d%H%M; }
ok "the index is generated at chat start" '[ -f "$K/INDEX.md" ] && grep -q "| shop/research | Ticket: pricing question |" "$K/INDEX.md"'
ok "the index gives the shortest start command for each track" 'grep -q "\`/keep:start research\`" "$K/INDEX.md" && grep -q "\`/keep:start main\`" "$K/INDEX.md" && grep -q "\`/keep:start tickets\`" "$K/INDEX.md"'
bash "$H/scripts/index.sh" "$R"; bash "$H/scripts/index.sh" "$R"
ok "git ignores the index, listed once" '[ "$(grep -cx INDEX.md "$K/.gitignore")" = 1 ]'
touch -t 202001010000 "$K/INDEX.md"
bash "$H/scripts/index.sh" "$R"
ok "an unchanged index isn't rewritten" '[ "$(date -r "$K/INDEX.md" +%Y)" = 2020 ]'
sed 's/line number 1 that/line number one that/' "$K/shop/tickets/STATE.md" > "$R/s.tmp" && mv "$R/s.tmp" "$K/shop/tickets/STATE.md"
edit s1 Edit "$K/shop/tickets/STATE.md"
ok "saving a changed state refreshes the index" 'grep -q "line number one that" "$K/INDEX.md"'
touch -t "$(ago 20)" "$K/solo/main/STATE.md"
out=$(bash "$H/scripts/status.sh" "$R")
ok "a track untouched for 14+ days is flagged in the listing" '[[ "$out" == *"solo/main: Ticket: none (start: /keep:start main) (idle 20 days; close it with /keep:close solo/main)"* ]]'
bash "$H/scripts/index.sh" "$R"
ok "and in the index" 'grep -q "idle 20 days: \`/keep:close solo/main\`?" "$K/INDEX.md"'
out=$(KEEP_IDLE_DAYS=30 bash "$H/scripts/status.sh" "$R")
ok "KEEP_IDLE_DAYS moves the threshold" '[[ "$out" != *idle* ]]'
printf 'x\n' > "$st/track-old"; touch -t "$(ago 40)" "$st/track-old"
printf 'x\n' > "$st/track-fresh"
touch -t "$(ago 40)" "$st/track-s1"
out=$(hook load '{"session_id":"s1","source":"resume"}')
ok "old session files are cleared at chat start" '[ ! -f "$st/track-old" ] && [ -f "$st/track-fresh" ] && [ -f "$st/.gitignore" ]'
ok "the current chat keeps its binding even if its file was old" '[ "$(cat "$st/track-s1" 2>/dev/null)" = shop/tickets ] && [[ "$out" == *"Active track: shop/tickets"* ]]'

echo "--- closing"
out=$(bash "$H/scripts/archive.sh" "$R" shop/research)
ok "closing a track moves it into the archive" '[ -f "$K/_archive/shop/research/STATE.md" ] && [ ! -e "$K/shop/research" ] && [[ "$out" == *"Moved .keep/shop/research to .keep/_archive/shop/research"* ]]'
ok "both chats bound to it are unbound, others keep theirs" '[ ! -f "$st/track-s2" ] && [ ! -f "$st/track-s5" ] && [ -f "$st/track-s1" ] && [[ "$out" == *"Chats unbound: 2"* ]]'
ok "the index drops it and counts the archive" '! grep -q "shop/research" "$K/INDEX.md" && grep -q "Archived tracks: 1" "$K/INDEX.md"'
out=$(bash "$H/scripts/status.sh" "$R")
ok "the archive never shows up as a feature" '[[ "$out" != *_archive* ]] && [ "$(printf "%s\n" "$out" | wc -l | tr -d " ")" = 2 ]'
mkdir -p "$K/shop/research" && cp "$K/_archive/shop/research/STATE.md" "$K/shop/research/STATE.md"
out=$(bash "$H/scripts/archive.sh" "$R" shop/research)
ok "closing a name already archived keeps both" '[ -d "$K/_archive/shop/research" ] && [ "$(ls -d "$K"/_archive/shop/research-* | wc -l | tr -d " ")" = 1 ]'
edit s3 Edit "$K/solo/main/STATE.md"
ok "(setup) solo/main has a stamp" '[ -e "$st/stamp-solo@main" ]'
out=$(bash "$H/scripts/archive.sh" "$R" solo)
ok "closing a feature archives all of it" '[ -f "$K/_archive/solo/FEATURE.md" ] && [ -f "$K/_archive/solo/main/STATE.md" ] && [ ! -e "$K/solo" ] && [ ! -f "$st/track-s3" ]'
ok "closing removes the stamps" '[ ! -e "$st/stamp-solo@main" ] && [ -e "$st/stamp-shop@tickets" ]'
for t in "../shop" "shop/nope" "_archive" "nothing"; do
  out=$(bash "$H/scripts/archive.sh" "$R" "$t" 2>&1; echo "exit=$?")
  ok "closing is refused for: $t" '[[ "$out" == *"exit=1"* ]]'
done
out=$(hook bind '{"session_id":"s7","prompt":"/keep:start _archive/shop"}')
ok "an archived track can't be bound" '[ -z "$out" ] && [ ! -f "$st/track-s7" ]'
edit s1 Edit "$K/_archive/shop/research/STATE.md"
ok "editing the archive doesn't mark the chat dirty" '[ ! -f "$st/dirty-s1" ]'

echo "--- bad input"
for h in bind load track stop; do
  out=$(printf 'not json' | "$H/hooks/$h.sh"; echo "exit=$?")
  ok "$h ignores bad input" '[ "$out" = "exit=0" ]'
done

echo "--- helper scripts"
out=$(bash "$H/scripts/status.sh" "$R")
ok "status lists the tracks still open" '[ "$out" = "- shop/tickets: [assumed] a very long current line number one that keeps going — with · marks (start: /keep:start shop)" ]'
out=$(bash "$H/scripts/status.sh" "$R/api")
ok "status says when a folder has no keep folder" '[[ "$out" == *"No keep folder at $R/api/.keep"* ]]'
out=$(bash "$H/scripts/freshness.sh" "$R" shop/research)
ok "freshness says when there's no stamp" '[[ "$out" == *"No git stamp yet"* ]]'

echo "--- chats side by side"
errs=$( { for i in 1 2 3 4 5 6 7 8; do bash "$H/scripts/index.sh" "$R" & done; wait; } 2>&1 )
ok "parallel index runs don't collide or leave temp files" '[ -z "$errs" ] && [ -z "$(ls "$K"/INDEX.md.* "$st"/INDEX.* 2>/dev/null)" ] && grep -q "shop/tickets" "$K/INDEX.md"'
F=$(mktemp -d "${TMPDIR:-/tmp}/keep-fresh.XXXXXX"); mkdir -p "$F/.keep"
bash "$H/scripts/index.sh" "$F"
ok "the index's temp files go to a git-ignored .state/, even on a fresh keep folder" '[ "$(cat "$F/.keep/.state/.gitignore")" = "*" ] && grep -q "mktemp \"\$keep/.state/" "$H/scripts/index.sh"'
rm -rf "$F"
T=$(mktemp -d "${TMPDIR:-/tmp}/keep-big.XXXXXX"); q "$T" init -b main; q "$T" -c user.name=t -c user.email=t@example.com commit --allow-empty -m s
dd if=/dev/zero of="$T/big.bin" bs=1048576 count=300 2>/dev/null
t0=$(date +%s); changes_out=$(. "$H/scripts/common.sh"; changes_fingerprint "$T"); t1=$(date +%s)
ok "a 300 MB untracked file doesn't slow the fingerprint ($((t1 - t0))s)" '[ $((t1 - t0)) -le 1 ] && [ -n "$changes_out" ]'
rm -rf "$T"
printf 'scratch' > "$K/.gitignore"
bash "$H/scripts/index.sh" "$R"
ok "appending to a .gitignore without a final newline keeps lines apart" '[ "$(cat "$K/.gitignore")" = "$(printf "scratch\nINDEX.md")" ]'

echo "--- worktree sessions"
W=$(mktemp -d "${TMPDIR:-/tmp}/keep-wt.XXXXXX")
q "$W" init -b main; q "$W" -c user.name=t -c user.email=t@example.com commit --allow-empty -m "start"
q "$W" worktree add -b worktree-w1 "$W/.claude/worktrees/w1"
mkdir -p "$W/.keep/app/main"
printf '# Feature: app\n' > "$W/.keep/app/FEATURE.md"
state app/main "none" "none" > "$W/.keep/app/main/STATE.md"
wt() { printf '%s' "$2" | CLAUDE_PROJECT_DIR="$W" "$H/hooks/$1.sh"; }
wt bind '{"session_id":"w","prompt":"/keep:start app/main"}' >/dev/null
wt track "{\"session_id\":\"w\",\"cwd\":\"$W/.claude/worktrees/w1/src\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$W/.keep/app/main/STATE.md\"}}"
ok "in a worktree session the project repo is stamped in the worktree" '[ "$(cut -f2 "$W/.keep/.state/stamp-app@main")" = "$(git -C "$W/.claude/worktrees/w1" rev-parse HEAD)" ] && [ "$(cut -f3 "$W/.keep/.state/stamp-app@main")" = worktree-w1 ]'
q "$W/.claude/worktrees/w1" -c user.name=t -c user.email=t@example.com commit --allow-empty -m "worktree work"
out=$(wt load "{\"session_id\":\"w\",\"source\":\"resume\",\"cwd\":\"$W/.claude/worktrees/w1\"}")
ok "and checked there at the next start" '[[ "$out" == *". in worktree w1 (worktree-w1): 1 new commit(s)"* && "$out" == *"worktree work"* ]]'
rm -rf "$W"

echo "--- skill commands"
ok "nothing refers to a custom keep folder anymore" '! grep -rq KEEP_FOLDER "$H"'
ok "skills run commands from the project root, not the working directory" '[ -z "$(grep -n "PWD" "$H"/skills/*/SKILL.md | grep -v "freshness.sh")" ]'
ok "every skill command that touches .keep goes through the project root" '[ -z "$(grep -nE "\`(bash|git|grep)[^\`]*\.keep" "$H"/skills/*/SKILL.md | grep -v CLAUDE_PROJECT_DIR)" ]'

echo "---"
echo "passed $pass, failed $fail"
[ "$fail" = 0 ]
