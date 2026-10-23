#!/usr/bin/env bash
# Runs the keep hooks against simulated hook inputs in a scratch project. Usage: bash tests/hooks.test.sh
set -uo pipefail
H="$(cd "$(dirname "$0")/../plugins/keep" && pwd)"
R=$(mktemp -d "${TMPDIR:-/tmp}/keep-test.XXXXXX")
trap 'rm -rf "$R"' EXIT
export CLAUDE_PROJECT_DIR="$R"
unset COMPACT_LIMIT KEEP_IDLE_DAYS KEEP_STATE_DAYS KEEP_SAVE_MINUTES
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
ok "and asks the agent, once, whether to keep new work in a track" '[[ "$out" == *"ask once whether to keep that work in a track"* && "$out" == *"Act only after the user agrees"* ]]'
ok "for real work only, matching a track or offering a new one" '[[ "$out" == *"starts work"* && "$out" == *"not a quick question"* && "$out" == *"offer to create a track if none matches"* ]]'
X=$(mktemp -d "${TMPDIR:-/tmp}/keep-none.XXXXXX"); mkdir -p "$X/.keep"
out=$(printf '{"session_id":"x1","source":"startup"}' | CLAUDE_PROJECT_DIR="$X" "$H/hooks/load.sh")
ok "a keep folder with no tracks yet still offers to create one" '[[ "$out" == *"offer to create a track"* && "$out" != *"Tracks, their"* ]]'
rm -rf "$X"
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
hook bind '{"session_id":"s8","prompt":"/keep:start solo fix the totals"}' >/dev/null
ok "so are words after a single name" '[ "$(cat "$st/track-s8" 2>/dev/null)" = solo/main ]'; rm -f "$st/track-s8"

echo "--- binding from the start skill"
out=$(bash "$H/scripts/bind.sh" "$R" b1 research)
ok "the bind script binds a single name" '[ "$out" = "Bound this chat to shop/research." ] && [ "$(cat "$st/track-b1")" = shop/research ]'
out=$(hook bind '{"session_id":"b1","prompt":"yes, go ahead"}')
ok "the next prompt names the chat after the track" '[ "$(jq -r .hookSpecificOutput.sessionTitle <<<"$out")" = shop/research ] && [ ! -f "$st/title-b1" ]'
out=$(hook bind '{"session_id":"b1","prompt":"and then this"}')
ok "only once" '[ -z "$out" ]'
bash "$H/scripts/bind.sh" "$R" b1 shop/research >/dev/null
ok "binding the same track again doesn't rename the chat" '[ ! -f "$st/title-b1" ]'
out=$(hook bind '{"session_id":"b2","prompt":"/keep:start shop/tickets"}'); bash "$H/scripts/bind.sh" "$R" b2 shop/tickets >/dev/null
ok "after a typed /keep:start, the skill's bind is a no-op" '[ "$(cat "$st/track-b2")" = shop/tickets ] && [ ! -f "$st/title-b2" ]'
for a in "b1 shop" "b1 nope" "b1 ../shop/tickets" "b1 shop/tickets/extra" '${CLAUDE_SESSION_ID} research' "b3"; do
  out=$(bash "$H/scripts/bind.sh" "$R" $a 2>&1; echo "exit=$?")
  ok "the bind script refuses: $a" '[[ "$out" == *"exit=1"* ]] && [ "$(cat "$st/track-b1")" = shop/research ] && [ ! -f "$st/track-b3" ]'
done
touch "$st/dirty-b2"
out=$(hook bind '{"session_id":"b2","prompt":"/keep:start research"}')
ok "a typed switch with unsaved work doesn't rebind" '[ -z "$out" ] && [ "$(cat "$st/track-b2")" = shop/tickets ]'
out=$(bash "$H/scripts/bind.sh" "$R" b2 research 2>&1; echo "exit=$?")
ok "and the bind script says to save it there first" '[[ "$out" == *"unsaved work on shop/tickets. Save it there first"* && "$out" == *"exit=2"* ]] && [ "$(cat "$st/track-b2")" = shop/tickets ]'
rm -f "$st/dirty-b2"
out=$(bash "$H/scripts/bind.sh" "$R" b2 research)
ok "once it's saved, the chat switches" '[ "$out" = "Bound this chat to shop/research." ] && [ "$(cat "$st/title-b2")" = shop/research ]'
touch "$st/dirty-b2"
out=$(bash "$H/scripts/bind.sh" "$R" b2 off)
ok "off unbinds the chat and says its unsaved work wasn't saved" '[ ! -f "$st/track-b2" ] && [ ! -f "$st/dirty-b2" ] && [ "$out" = "Unbound this chat from shop/research. Its work since the last save wasn'"'"'t saved there." ]'
out=$(hook bind '{"session_id":"b2","prompt":"ok"}')
ok "the chat is renamed so its title can't rebind it" '[ "$(jq -r .hookSpecificOutput.sessionTitle <<<"$out")" = "shop/research (unbound)" ]'
out=$(hook load '{"session_id":"b9","source":"clear","session_title":"shop/research (unbound)"}')
ok "a cleared chat with that title stays unbound" '[ ! -f "$st/track-b9" ] && [[ "$out" == *"No keep track is bound"* ]]'
out=$(bash "$H/scripts/bind.sh" "$R" b2 off)
ok "off on an unbound chat says so" '[ "$out" = "This chat isn'"'"'t bound to a track." ]'
hook bind '{"session_id":"b4","prompt":"/keep:start shop/tickets"}' >/dev/null
out=$(hook bind '{"session_id":"b4","prompt":"/keep:start off"}')
ok "a typed /keep:start off unbinds and renames at once" '[ ! -f "$st/track-b4" ] && [ "$(jq -r .hookSpecificOutput.sessionTitle <<<"$out")" = "shop/tickets (unbound)" ]'
B=$(mktemp -d "${TMPDIR:-/tmp}/keep-nojq.XXXXXX")
for c in dirname mkdir cat basename wc tr rm; do ln -s "$(command -v "$c")" "$B/$c"; done
out=$(PATH="$B" /bin/bash "$H/scripts/bind.sh" "$R" j1 research)
ok "without jq, binding says keep's hooks are off" '[[ "$out" == *"Bound this chat to shop/research."* && "$out" == *"jq isn'"'"'t installed"* ]]'
out=$(bash "$H/scripts/bind.sh" "$R" j2 research)
ok "with jq it doesn't" '[[ "$out" != *jq* ]]'
rm -rf "$B"; rm -f "$st/track-b1" "$st/track-b2" "$st/track-j1" "$st/track-j2" "$st"/title-*
ok "the agent can run every skill, close included, when the user asks" '! grep -q "disable-model-invocation" "$H"/skills/*/SKILL.md && grep -q "asks in words to close one; never on your own" "$H/skills/close/SKILL.md"'
for p in "/keep:start shop" "/keep:start shop/nope" "/keep:start ../shop/tickets" "/keep:start .state/x" "hello /keep:start shop/tickets" "/keep:startshop/tickets" "/keep:start shop/tickets/extra"; do
  out=$(hook bind "{\"session_id\":\"s4\",\"prompt\":\"$p\"}")
  ok "no binding for: $p" '[ -z "$out" ] && [ ! -f "$st/track-s4" ]'
done

echo "--- loading"
out=$(hook load '{"session_id":"s1","source":"resume"}')
ok "bound chat loads feature, context and state" '[[ "$out" == *"Active track: shop/tickets"* && "$out" == *"**Repos:** api, web"* && "$out" == *"ship tickets"* && "$out" == *"T-7 checkout fix"* ]]'
ok "it gives the short command that starts the track in a new chat" '[[ "$out" == *"Active track: shop/tickets (a new chat starts it with /keep:start tickets)"* ]]'
ok "it asks for decisions to be recorded when they're made" '[[ "$out" == *"Record each decision as soon as it'"'"'s made"* ]]'
ok "without a stamp it says nothing was checked against git" '[[ "$out" == *"No git stamp yet"* ]]'
ok "no compaction notes on resume" '[[ "$out" != *compacted* ]]'

echo "--- the current track"
out=$(bash "$H/scripts/current.sh" "$R" s1)
ok "current shows this chat's track, its current work, next step and start command" '[[ "$out" == *"This chat is on shop/tickets. A new chat starts it with /keep:start tickets."* && "$out" == *"Current: Ticket: T-7 checkout fix"* && "$out" == *"Next step: edit api/cart.js applyDiscount"* ]]'
out=$(bash "$H/scripts/current.sh" "$R" nobody)
ok "an unbound chat is told so, with the tracks to pick from" '[[ "$out" == *"This chat isn'"'"'t bound to a track."* && "$out" == *"- shop/research:"* ]]'
out=$(bash "$H/scripts/current.sh" "$R" "../x" 2>&1; echo "exit=$?")
ok "current refuses a bad session id" '[[ "$out" == *"exit=1"* ]]'
out=$(hook load '{"session_id":"s1","source":"resume"}')
ok "a bound chat is told a track may be called a workspace" '[[ "$out" == *"The user may call a track a workspace; /keep:current shows this one."* ]]'
out=$(hook load '{"session_id":"nobody","source":"startup"}')
ok "so is an unbound one" '[[ "$out" == *"The user may call a track a workspace."* ]]'
ok "every skill about tracks mentions the word workspace" '[ -z "$(grep -L "workspace" "$H"/skills/{start,current,list,rename,close,save,next,done}/SKILL.md)" ]'

echo "--- chats the user named"
nf() { (. "$H/scripts/common.sh"; name_file "$K" "$1"); }
hook load '{"session_id":"u1","source":"startup","session_title":"CASH-508 withdrawal"}' >/dev/null
ok "keep records the name a user gave a chat" '[ "$(cat "$st/name-u1")" = "CASH-508 withdrawal" ]'
out=$(hook bind '{"session_id":"u1","prompt":"/keep:start shop/tickets"}')
ok "binding it keeps that name and remembers its track" '[ -z "$out" ] && [ "$(cat "$st/track-u1")" = shop/tickets ] && [ "$(cat "$(nf "CASH-508 withdrawal")")" = shop/tickets ]'
out=$(hook load '{"session_id":"u2","source":"clear","session_title":"CASH-508 withdrawal"}')
ok "after /clear the same name finds the track again" '[[ "$out" == *"Active track: shop/tickets"* ]] && [ "$(cat "$st/track-u2")" = shop/tickets ]'
hook load '{"session_id":"u3","source":"resume","session_title":"shop/research"}' >/dev/null
ok "a title keep set isn't taken for the user's name" '[ ! -f "$st/name-u3" ] && [ "$(cat "$st/track-u3")" = shop/research ]'
hook load '{"session_id":"u4","source":"startup","session_title":"My review"}' >/dev/null
bash "$H/scripts/bind.sh" "$R" u4 research >/dev/null
ok "the start skill's bind keeps a named chat's name too" '[ ! -f "$st/title-u4" ] && [ "$(cat "$(nf "My review")")" = shop/research ]'
out=$(hook bind '{"session_id":"u1","prompt":"/keep:start off"}')
hook load '{"session_id":"u5","source":"clear","session_title":"CASH-508 withdrawal"}' >/dev/null
ok "unbinding a named chat keeps its name and forgets its track" '[ -z "$out" ] && [ ! -f "$st/track-u1" ] && [ ! -f "$(nf "CASH-508 withdrawal")" ] && [ ! -f "$st/track-u5" ]'
rm -f "$st"/track-u2 "$st"/track-u3 "$st"/track-u4

echo "--- a chat that moved to another folder"
M=$(mktemp -d "${TMPDIR:-/tmp}/keep-moved.XXXXXX")
out=$(printf '{"session_id":"mv1","prompt":"/keep:start shop/tickets","cwd":"%s"}' "$R/api" | CLAUDE_PROJECT_DIR="$M" "$H/hooks/bind.sh")
ok "a chat that started elsewhere finds the keep folder from where it works now" '[ "$(cat "$st/track-mv1" 2>/dev/null)" = shop/tickets ] && [ "$(jq -r .hookSpecificOutput.sessionTitle <<<"$out")" = shop/tickets ]'
out=$(printf '{"session_id":"mv1","source":"resume","cwd":"%s"}' "$R/api" | CLAUDE_PROJECT_DIR="$M" "$H/hooks/load.sh")
ok "and loads its track" '[[ "$out" == *"Active track: shop/tickets"* ]]'
printf '{"session_id":"mv1","tool_name":"Edit","tool_input":{"file_path":"%s"},"cwd":"%s"}' "$R/api/cart.js" "$R/api" | CLAUDE_PROJECT_DIR="$M" "$H/hooks/track.sh"
ok "and counts its edits" '[ -f "$st/dirty-mv1" ]'
out=$(cd "$R/api" && bash "$H/scripts/status.sh" "$M")
ok "the scripts find it the same way" '[[ "$out" == *"shop/tickets"* ]]'
out=$(printf '{"session_id":"mv2","prompt":"/keep:start shop/tickets","cwd":"%s"}' "$M" | CLAUDE_PROJECT_DIR="$M" "$H/hooks/bind.sh"; echo "exit=$?")
ok "with no keep folder at or above it, keep stays silent" '[ "$out" = "exit=0" ] && [ ! -e "$M/.keep" ]'
missing=""
for f in "$H"/skills/*/SKILL.md; do
  grep -q "CLAUDE_PROJECT_DIR" "$f" && ! grep -q "has no \`.keep/\` folder, which happens when a chat moves" "$f" && missing="$missing ${f#$H/}"
done
ok "every skill that uses the project folder says what to do when it has no .keep/${missing:+ (missing:$missing)}" '[ -z "$missing" ]'
rm -f "$st/track-mv1" "$st/dirty-mv1"; rm -rf "$M"

echo "--- tracking and the Stop gate"
edit() { hook track "{\"session_id\":\"$1\",\"tool_name\":\"$2\",\"tool_input\":{\"file_path\":\"$3\"}}"; }
stop() { hook stop "{\"session_id\":\"$1\",\"stop_hook_active\":$2}"; }
out=$(stop s1 false);                                  ok "stop passes while clean" '[ -z "$out" ]'
edit s1 Edit "$K/shop/FEATURE.md";                     ok "editing keep files stays clean" '[ ! -f "$st/dirty-s1" ]'
edit s1 Edit "$K/shop/research/STATE.md";              ok "editing another track's state stays clean" '[ ! -f "$st/dirty-s1" ]'
edit s1 Edit "$R/.claude/settings.json";               ok "editing the project's .claude stays clean" '[ ! -f "$st/dirty-s1" ]'
edit s1 Write "$HOME/.claude/projects/p/memory/MEMORY.md"; ok "writing Claude's own memory or plans stays clean" '[ ! -f "$st/dirty-s1" ]'
edit s1 Write "/tmp/keep-elsewhere/scratch-note.md";   ok "an edit outside the project folder stays clean" '[ ! -f "$st/dirty-s1" ]'
edit s1 Edit "$R/.claude/worktrees/w1/api/cart.js";    ok "an edit in a Claude Code worktree marks the chat dirty" '[ -f "$st/dirty-s1" ]'; rm -f "$st/dirty-s1"
edit s1 Edit "$R/api/.claude/notes.md";                ok "a repo's own .claude folder counts as project files" '[ -f "$st/dirty-s1" ]'; rm -f "$st/dirty-s1"
edit s1 Edit "$R/api/cart.js";                         ok "a project edit marks the chat dirty" '[ -f "$st/dirty-s1" ]'
out=$(stop s1 false);                                  ok "a chat that hasn't saved yet is asked at its first working turn" '[ -n "$out" ]'
edit s1 Edit "$K/shop/tickets/STATE.md"; edit s1 Edit "$R/api/cart.js"
ok "(setup) saving starts this chat's own clock" '[ -f "$st/saved-s1" ] && [ -f "$st/dirty-s1" ]'
out=$(stop s1 false);                                  ok "stop waits while this chat saved in the last 15 minutes" '[ -z "$out" ] && [ -f "$st/dirty-s1" ]'
out=$(KEEP_SAVE_MINUTES=0 stop s1 false);              ok "KEEP_SAVE_MINUTES=0 asks after every working turn" '[ -n "$out" ]'
mins_ago() { date -v-"$1"M +%Y%m%d%H%M 2>/dev/null || date -d "$1 minutes ago" +%Y%m%d%H%M; }
touch -t "$(mins_ago 20)" "$st/saved-s1"
out=$(KEEP_SAVE_MINUTES=30 stop s1 false);             ok "KEEP_SAVE_MINUTES moves the wait" '[ -z "$out" ]'
hook bind '{"session_id":"s10","prompt":"/keep:start shop/tickets"}' >/dev/null; edit s10 Edit "$K/shop/tickets/STATE.md"
out=$(stop s1 false)
ok "another chat saving the same track doesn't silence this one" '[ -n "$out" ]'; rm -f "$st/track-s10" "$st/saved-s10"
ok "stop sends Stop hook feedback naming the state file" '[ "$(jq -r .hookSpecificOutput.hookEventName <<<"$out")" = Stop ] && [[ "$(jq -r .hookSpecificOutput.additionalContext <<<"$out")" == *".keep/shop/tickets/STATE.md"* ]] && [ "$(jq -r ".decision // empty" <<<"$out")" = "" ]'
ok "and asks for Current, Next step and new decisions, nothing more" '[[ "$(jq -r .hookSpecificOutput.additionalContext <<<"$out")" == *"Update its Current and Next step"* && "$(jq -r .hookSpecificOutput.additionalContext <<<"$out")" == *"Record any decision made since"* && "$(jq -r .hookSpecificOutput.additionalContext <<<"$out")" != *"Done log"* ]]'
out=$(KEEP_SAVE_MINUTES=soon stop s1 false);           ok "a bad KEEP_SAVE_MINUTES falls back to 15" '[ -n "$out" ]'
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
ok "the second asks for /keep:save and a fresh chat" '[[ "$out" == *"compacted 2 time"* && "$out" == *"/keep:save"* && "$out" == *"start a new chat with /keep:start tickets"* ]]'
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
printf '# Track: shop/tickets\n**Goal:** ship tickets\n%s\n**Rules for this track:**\n- the last rule\n' "$(head -c 2200 < /dev/zero | tr '\0' 'x')" > "$K/shop/tickets/CONTEXT.md"
out=$(hook load '{"session_id":"s1","source":"resume"}')
ok "a CONTEXT.md up to about 2,500 bytes loads whole, rules included" '[[ "$out" == *"- the last rule"* ]]'
printf '# Track: shop/tickets\n**Goal:** ship tickets\n' > "$K/shop/tickets/CONTEXT.md"

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
printf '# Track: solo/main\n\n**Goal:** keep the lights on\n' > "$K/solo/main/CONTEXT.md"
out=$(bash "$H/scripts/status.sh" "$R")
ok "a track with nothing in flight shows its goal" '[[ "$out" == *"solo/main: Goal: keep the lights on (start:"* ]]'
printf '# Track: solo/main\n\n**Goal:** <what this line of work delivers>\n' > "$K/solo/main/CONTEXT.md"
out=$(bash "$H/scripts/status.sh" "$R")
ok "but not the template's placeholder" '[[ "$out" == *"solo/main: Ticket: none (start:"* ]]'
rm -f "$K/solo/main/CONTEXT.md"
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
ok "closing forgets the names remembered for it" '[ ! -f "$(nf "My review")" ]'
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
O=$(mktemp -d "${TMPDIR:-/tmp}/keep-none.XXXXXX")
out=$(cd "$O" && bash "$H/scripts/status.sh" "$R/api"); rm -rf "$O"
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
ok "the agent is told the chat can read the track but not save it" '[[ "$out" == *"can read the track but can'"'"'t update STATE.md"* ]]'
out=$(wt load '{"session_id":"w","source":"resume"}')
ok "a main-checkout chat isn't told that" '[[ "$out" != *"can read the track"* ]]'
wt track "{\"session_id\":\"w\",\"cwd\":\"$W/.claude/worktrees/w1\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$W/.claude/worktrees/w1/app.js\"}}"
touch -t "$(mins_ago 20)" "$W/.keep/.state/saved-w"
out=$(wt stop "{\"session_id\":\"w\",\"stop_hook_active\":false,\"cwd\":\"$W/.claude/worktrees/w1\"}")
ok "a worktree session isn't asked to save what it can't" '[ -f "$W/.keep/.state/dirty-w" ] && [ -z "$out" ]'
out=$(wt stop '{"session_id":"w","stop_hook_active":false}')
ok "the same chat state in the main checkout is asked" '[ -n "$out" ]'
rm -rf "$W"

echo "--- a keep folder inside the project's repo"
G=$(mktemp -d "${TMPDIR:-/tmp}/keep-one.XXXXXX")
q "$G" init -b main; q "$G" -c user.name=t -c user.email=t@example.com commit --allow-empty -m "start"
mkdir -p "$G/.keep/app/main"
printf '# Feature: app\n\n**Repos:** .\n' > "$G/.keep/app/FEATURE.md"
state app/main "none" "none" > "$G/.keep/app/main/STATE.md"
g() { printf '%s' "$2" | CLAUDE_PROJECT_DIR="$G" "$H/hooks/$1.sh"; }
g bind '{"session_id":"g","prompt":"/keep:start app"}' >/dev/null
g track "{\"session_id\":\"g\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$G/.keep/app/main/STATE.md\"}}"
ok "the stamp doesn't count keep's own files as changes" '[ "$(cut -f4 "$G/.keep/.state/stamp-app@main")" = 0 ]'
later=$(date -v+2M +%Y%m%d%H%M 2>/dev/null || date -d '2 minutes' +%Y%m%d%H%M)
printf 'a later note\n' > "$G/.keep/app/main/NOTES.md"; touch -t "$later" "$G/.keep/app/main/NOTES.md"
out=$(bash "$H/scripts/freshness.sh" "$G" app/main)
ok "nor does freshness, after a keep file changes" '[[ "$out" == *"- . (main): no changes"* ]]'
printf 'x\n' > "$G/real.txt"; touch -t "$later" "$G/real.txt"
out=$(bash "$H/scripts/freshness.sh" "$G" app/main)
ok "a real untracked file still counts" '[[ "$out" == *"uncommitted changes differ: 1 file(s) now, 0 then"* ]]'
rm -f "$G/real.txt"
gitenv() { GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com "$@"; }
out=$(gitenv bash "$H/scripts/setup-git.sh" "$G" 2>&1; echo "exit=$?")
ok "setup-git needs a choice" '[[ "$out" == *"exit=1"* ]] && [ ! -e "$G/.keep/.git" ]'
out=$(gitenv bash "$H/scripts/setup-git.sh" "$G" ignore history)
ok "setup-git keeps .keep/ out of the project's git" '[ -z "$(git -C "$G" status --porcelain)" ] && grep -qx "/.keep/" "$G/.git/info/exclude"'
ok "and gives it its own history" '[ "$(git -C "$G/.keep" rev-list --count HEAD 2>/dev/null)" = 1 ] && [ -z "$(git -C "$G/.keep" ls-files .state INDEX.md)" ]'
out=$(gitenv bash "$H/scripts/setup-git.sh" "$G" ignore history)
ok "running it again changes nothing" '[ -z "$out" ] && [ "$(grep -cx "/.keep/" "$G/.git/info/exclude")" = 1 ]'
mkdir -p "$G/sub/.keep"
gitenv bash "$H/scripts/setup-git.sh" "$G/sub" ignore >/dev/null
ok "a project in a repo's subfolder is excluded by its own path, and ignore alone adds no history" 'grep -qx "/sub/.keep/" "$G/.git/info/exclude" && [ -z "$(git -C "$G" status --porcelain)" ] && [ ! -e "$G/sub/.keep/.git" ]'
N=$(mktemp -d "${TMPDIR:-/tmp}/keep-nogit.XXXXXX"); mkdir -p "$N/.keep"
out=$(gitenv bash "$H/scripts/setup-git.sh" "$N" ignore history)
ok "outside a git repo it says there's nothing to ignore and adds the history" '[ -d "$N/.keep/.git" ] && [[ "$out" == *"isn'"'"'t a git repo"* ]]'
rm -rf "$G" "$N"

echo "--- renaming"
N=$(mktemp -d "${TMPDIR:-/tmp}/keep-rename.XXXXXX"); NK="$N/.keep"; NS="$NK/.state"
mkdir -p "$NK/shop/tickets" "$NK/shop/research" "$NS"
printf '# Feature: shop\n' > "$NK/shop/FEATURE.md"
printf '# Decisions: shop\n' > "$NK/shop/DECISIONS.md"
for t in tickets research; do
  state "shop/$t" none none > "$NK/shop/$t/STATE.md"
  printf '# Track: shop/%s\n\n**Goal:** %s work\n' "$t" "$t" > "$NK/shop/$t/CONTEXT.md"
done
printf -- '- 2026-10-22 · from shop/tickets · a note\n' >> "$NK/shop/research/STATE.md"
printf 'shop/tickets\n' > "$NS/track-n1"; printf 'shop/tickets\n' > "$NS/track-n2"; printf 'shop/research\n' > "$NS/track-n3"
printf 'x\n' > "$NS/stamp-shop@tickets"; printf '1 2 x\n' > "$NS/deep-shop@tickets"
printf 'shop/tickets\n' > "$NS/track-n4"; printf 'Review chat\n' > "$NS/name-n4"
NF=$(. "$H/scripts/common.sh"; name_file "$NK" "Review chat"); printf 'shop/tickets\n' > "$NF"
out=$(bash "$H/scripts/rename.sh" "$N" shop/tickets build)
ok "renaming a track moves its folder and updates its headers" '[ -f "$NK/shop/build/STATE.md" ] && [ ! -e "$NK/shop/tickets" ] && head -1 "$NK/shop/build/STATE.md" | grep -qx "# State: shop/build" && head -1 "$NK/shop/build/CONTEXT.md" | grep -qx "# Track: shop/build"'
ok "its chats stay bound and get the new name at their next message" '[ "$(cat "$NS/track-n1")" = shop/build ] && [ "$(cat "$NS/track-n2")" = shop/build ] && [ "$(cat "$NS/title-n1")" = shop/build ] && [ "$(cat "$NS/track-n3")" = shop/research ] && [ ! -f "$NS/title-n3" ] && [[ "$out" == *"renamed at their next message: 2"* ]]'
ok "a chat the user named stays bound, keeps its name, and its remembered track follows" '[ "$(cat "$NS/track-n4")" = shop/build ] && [ ! -f "$NS/title-n4" ] && [ "$(cat "$NF")" = shop/build ] && [[ "$out" == *"Chats kept bound: 3, renamed at their next message: 2"* ]]'
ok "its stamp and deep-review record follow it" '[ -f "$NS/stamp-shop@build" ] && [ ! -e "$NS/stamp-shop@tickets" ] && [ -f "$NS/deep-shop@build" ] && [ ! -e "$NS/deep-shop@tickets" ]'
ok "its stamp follows it" '[ -f "$NS/stamp-shop@build" ] && [ ! -e "$NS/stamp-shop@tickets" ]'
ok "the index lists the new name" 'grep -q "| shop/build |" "$NK/INDEX.md" && ! grep -q "shop/tickets |" "$NK/INDEX.md"'
ok "other mentions of the old name are listed, not changed" '[[ "$out" == *"Still mention shop/tickets:"*".keep/shop/research/STATE.md"* ]] && grep -q "from shop/tickets" "$NK/shop/research/STATE.md"'
out=$(printf '{"session_id":"n1","prompt":"carry on"}' | CLAUDE_PROJECT_DIR="$N" "$H/hooks/bind.sh")
ok "the bind hook renames that chat at its next message" '[ "$(jq -r .hookSpecificOutput.sessionTitle <<<"$out")" = shop/build ] && [ ! -f "$NS/title-n1" ]'
out=$(bash "$H/scripts/rename.sh" "$N" shop store)
ok "renaming a feature moves it and every binding and stamp under it" '[ -f "$NK/store/build/STATE.md" ] && [ ! -e "$NK/shop" ] && [ "$(cat "$NS/track-n2")" = store/build ] && [ "$(cat "$NS/track-n3")" = store/research ] && [ -f "$NS/stamp-store@build" ] && head -1 "$NK/store/FEATURE.md" | grep -qx "# Feature: store" && head -1 "$NK/store/DECISIONS.md" | grep -qx "# Decisions: store" && head -1 "$NK/store/research/STATE.md" | grep -qx "# State: store/research"'
for a in "store/nope x" "store/build research" "store/build off" "store/build ../x" "nope x" "store research"; do
  mkdir -p "$NK/research"
  out=$(bash "$H/scripts/rename.sh" "$N" $a 2>&1; echo "exit=$?")
  ok "renaming is refused for: $a" '[[ "$out" == *"exit=1"* ]] && [ -f "$NK/store/build/STATE.md" ] && [ -f "$NK/store/research/STATE.md" ]'
done
rm -rf "$N"

echo "--- the automatic check"
A=$(mktemp -d "${TMPDIR:-/tmp}/keep-audit.XXXXXX"); AK="$A/.keep"; AS="$AK/.state"
mkdir -p "$AK/app/main" "$AS"
printf '# Feature: app\n\n**Goal:** an app\n' > "$AK/app/FEATURE.md"
printf '# Track: app/main\n\n**Goal:** build it\n' > "$AK/app/main/CONTEXT.md"
printf '# State: app/main\n\n## Inbox\n\n## Current\n- [verified] the parser works\n\n## Next step\n- edit src/parse.js parse()\n\n## Tickets\n- [ ] T-2: handle errors — acceptance: npm test passes\n' > "$AK/app/main/STATE.md"
printf '# Notes: app/main\n' > "$AK/app/main/NOTES.md"
au() { bash "$H/scripts/audit.sh" "$A" "${2:-app/main}" "$1"; }
out=$(au start);                                       ok "a clean track has nothing to report" '[ -z "$out" ]'
dup="- 2026-10-01 · T-1 · abc123 · this exact line is long enough to count as a duplicate"
{ printf '# State: app/main\n\n## Inbox\n- 2020-01-01 · app/other · old news · affects tickets\n\n## Current\n- working on the importer\n- [assumed] marked line\n\n## Next step\n\n## Tickets\n- [ ] T-3: no check here\n- [ ] T-2: handle errors — acceptance: npm test passes\n\n## Done log\n%s\n\n## Gotchas\n- %s\n' "$dup" "$(head -c 5000 < /dev/zero | tr '\0' 'g')"; } > "$AK/app/main/STATE.md"
{ printf '# Notes: app/main\n%s\n' "$dup"; head -c 16000 < /dev/zero | tr '\0' 'n'; printf '\n'; } > "$AK/app/main/NOTES.md"
printf '# Track: app/main\n\n**Read on start:**\n- `NOTES.md`\n- `docs/missing.md`\n\n**Rules for this track:**\n- <anything specific to this line of work>\n' > "$AK/app/main/CONTEXT.md"
out=$(au start)
ok "it flags a STATE.md over 5,000 bytes" '[[ "$out" == *"STATE.md is "*" bytes, over 5,000"* ]]'
ok "an empty Next step" '[[ "$out" == *"Next step is empty"* ]]'
ok "unmarked Current lines" '[[ "$out" == *"1 Current line(s) are not marked"* ]]'
ok "tickets without an acceptance check" '[[ "$out" == *"1 open ticket(s) in STATE.md have no acceptance check"* ]]'
ok "leftover template placeholders" '[[ "$out" == *"1 template placeholder line(s)"* ]]'
ok "files listed to read that don't exist" '[[ "$out" == *"names files that do not exist: docs/missing.md."* ]]'
ok "large files read at every start" '[[ "$out" == *"Read at every start but large: NOTES.md (15 KB)"* ]]'
ok "lines copied into both STATE.md and NOTES.md" '[[ "$out" == *"1 line(s) appear word for word in both STATE.md and NOTES.md"* ]]'
ok "and Inbox items older than two weeks" '[[ "$out" == *"1 Inbox item(s) are older than two weeks"* ]]'
out=$(au save);                                        ok "an unchanged track is skipped" '[ -z "$out" ]'
printf -- '- another gotcha\n' >> "$AK/app/main/STATE.md"
out=$(au save);                                        ok "a change that adds no new issue reports nothing" '[ -z "$out" ]'
sed 's/^## Next step$/## Next step\n- run npm test/' "$AK/app/main/STATE.md" > "$A/s" && mv "$A/s" "$AK/app/main/STATE.md"
out=$(au save);                                        ok "(setup) the fixed issue is dropped" '[ -z "$out" ] && ! grep -qx next-step "$AS/audit-app@main.told"'
sed '/^- run npm test$/d' "$AK/app/main/STATE.md" > "$A/s" && mv "$A/s" "$AK/app/main/STATE.md"
out=$(au save);                                        ok "an issue that comes back is reported again, alone" '[ "$out" = "- Next step is empty: write one concrete action (the file and function to touch, or the command to run)." ]'
out=$(au start);                                       ok "a chat start reports every open issue again" '[ "$(printf "%s\n" "$out" | wc -l | tr -d " ")" = 9 ]'
out=$(au due);                                         ok "a track never reviewed with notes over 10 KB is due" '[ "$out" = due ] && [ -f "$AS/deep-app@main.started" ] && [ ! -f "$AS/deep-app@main" ]'
out=$(au due);                                         ok "a review started in the last hour isn't started again" '[ -z "$out" ]'
touch -t "$(date -v-2H +%Y%m%d%H%M 2>/dev/null || date -d '2 hours ago' +%Y%m%d%H%M)" "$AS/deep-app@main.started"
out=$(au due);                                         ok "a review whose result was lost is started again after an hour" '[ "$out" = due ]'
au reviewed;                                           ok "a handled review is recorded" '[ -f "$AS/deep-app@main" ] && [ ! -f "$AS/deep-app@main.started" ]'
out=$(au due);                                         ok "then the track isn't due" '[ -z "$out" ]'
head -c 11000 < /dev/zero | tr '\0' 'm' >> "$AK/app/main/NOTES.md"
out=$(au due);                                         ok "notes that grew by 10 KB make it due again" '[ "$out" = due ]'
au reviewed
read -r _ size fp < "$AS/deep-app@main"; printf '%s %s %s\n' "$(( $(date +%s) - 1300000 ))" "$size" "$fp" > "$AS/deep-app@main"
out=$(au due);                                         ok "two weeks without changes isn't enough" '[ -z "$out" ]'
read -r _ size fp < "$AS/deep-app@main"; printf '%s %s %s\n' "$(( $(date +%s) - 1300000 ))" "$size" "old" > "$AS/deep-app@main"
out=$(au due);                                         ok "two weeks with changes is" '[ "$out" = due ]'
mkdir -p "$AK/app/small"; cp "$AK/app/FEATURE.md" "$AK/app/small/NOTES.md"
printf '# State: app/small\n\n## Current\n- [verified] fine\n\n## Next step\n- ship it\n' > "$AK/app/small/STATE.md"
out=$(au due app/small);                               ok "a small track isn't due, and starts its two-week clock" '[ -z "$out" ] && [ -f "$AS/deep-app@small" ]'
rm -f "$AS"/audit-app@main*
printf 'app/main\n' > "$AS/track-a1"; printf 'app/small\n' > "$AS/track-a2"
ae() { printf '{"session_id":"%s","tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$1" "$AK/$2/STATE.md" | CLAUDE_PROJECT_DIR="$A" "$H/hooks/track.sh"; }
out=$(ae a1 app/main)
ok "saving STATE.md tells the agent what to fix, in the same turn" '[ "$(jq -r .hookSpecificOutput.hookEventName <<<"$out")" = PostToolUse ] && [[ "$(jq -r .hookSpecificOutput.additionalContext <<<"$out")" == *"keep'"'"'s check of app/main after this save:"*"Next step is empty"*"Fix the ones that only move or de-duplicate text"* ]]'
out=$(ae a1 app/main);                                 ok "but only once" '[ -z "$out" ]'
out=$(ae a2 app/small);                                ok "a clean track's save adds nothing" '[ -z "$out" ]'
out=$(printf '{"session_id":"a1","source":"resume"}' | CLAUDE_PROJECT_DIR="$A" "$H/hooks/load.sh")
ok "a chat start lists the open issues for the agent" '[[ "$out" == *"keep'"'"'s check of this track:"*"Next step is empty"* ]]'
out=$(printf '{"session_id":"a2","source":"resume"}' | CLAUDE_PROJECT_DIR="$A" "$H/hooks/load.sh")
ok "and says nothing for a clean track" '[[ "$out" != *"keep'"'"'s check"* ]]'
rm -f "$AS"/deep-app@main*
err=$(printf '{"session_id":"a1","source":"resume"}' | CLAUDE_PROJECT_DIR="$A" "$H/hooks/load.sh" 2>&1 >/dev/null); rm -f "$AS"/deep-app@main.started
ok "a chat start on a due track writes nothing to stderr" '[ -z "$err" ]'
out=$(printf '{"session_id":"a1","source":"resume"}' | CLAUDE_PROJECT_DIR="$A" "$H/hooks/load.sh")
ok "a chat start on a due track asks the agent to start the review" '[[ "$out" == *"periodic review of this track is due. Start the keep audit skill for app/main now"* ]]'
out=$(printf '{"session_id":"a1","source":"resume"}' | CLAUDE_PROJECT_DIR="$A" "$H/hooks/load.sh")
ok "but not again while it runs" '[[ "$out" != *"periodic review"* ]]'
printf '{"session_id":"a1","tool_name":"Write","tool_input":{"file_path":"%s"}}' "$AK/app/main/review-2026-10-23.md" | CLAUDE_PROJECT_DIR="$A" "$H/hooks/track.sh"
ok "writing the review file marks the review as handled" '[ -f "$AS/deep-app@main" ] && [ ! -f "$AS/deep-app@main.started" ] && [ ! -f "$AS/dirty-a1" ]'
mkdir -p "$AK/app/big"
printf '# Track: app/big\n\n**Read on start:**\n- `NOTES.md`\n\n**Rules for this track:**\n%s\n' "$(for i in $(seq 1 30); do echo "- rule number $i that keeps the context file near its size limit"; done)" > "$AK/app/big/CONTEXT.md"
{ printf '# State: app/big\n\n## Inbox\n- 2026-10-20 · app/main · a note · affects tickets\n\n## Current\n- [verified] work\n\n## Next step\n- go\n\n## Tickets\n'; for i in $(seq 1 60); do echo "- [ ] T-$i: a ticket with a title long enough to fill the file — acceptance: a test"; done; } > "$AK/app/big/STATE.md"
for i in $(seq 1 500); do echo "- a reference note line number $i with some words in it"; done > "$AK/app/big/NOTES.md"
ms() { python3 -I -c 'import subprocess, sys, time; t = time.time(); subprocess.run(sys.argv[1:], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL); print(int((time.time() - t) * 1000))' "$@"; }
cold=$(ms bash "$H/scripts/audit.sh" "$A" app/big start); warm=$(ms bash "$H/scripts/audit.sh" "$A" app/big save)
ok "a full check of a large track takes under 500 ms (${cold} ms)" '[ "$cold" -lt 500 ]'
ok "an unchanged track is skipped in under 200 ms (${warm} ms)" '[ "$warm" -lt 200 ]'
G2=$(mktemp -d "${TMPDIR:-/tmp}/keep-audit2.XXXXXX"); mkdir -p "$G2/.keep/app/main"
printf '# State: app/main\n\n## Current\n- State as of today:\n  - [verified] the parser works\n\n## Next step\n- go\n' > "$G2/.keep/app/main/STATE.md"
out=$(bash "$H/scripts/audit.sh" "$G2" app/main start)
ok "the check creates keep's runtime folder with its git-ignore rule" '[ "$(cat "$G2/.keep/.state/.gitignore")" = "*" ]'
ok "a heading-style Current bullet ending in a colon isn't counted as unmarked" '[ -z "$out" ]'
D=$(mktemp -d "${TMPDIR:-/tmp}/keep-date.XXXXXX")
printf '#!/bin/sh\n[ "$1" = "+%%Y-%%m-%%d" ] && { echo 2099-01-01; exit 0; }\nexec /bin/date "$@"\n' > "$D/date"; chmod +x "$D/date"
before=$(head -1 "$G2/.keep/.state/audit-app@main"); PATH="$D:$PATH" bash "$H/scripts/audit.sh" "$G2" app/main start >/dev/null; after=$(head -1 "$G2/.keep/.state/audit-app@main")
ok "a new day rescans an unchanged track, since the Inbox check depends on the date" '[ "$before" != "$after" ]'
rm -rf "$G2" "$D"
ok "skills that run keep's scripts say to run them exactly as written" '[ -z "$(grep -L "Run each command below exactly as written" "$H"/skills/{start,save,done,close,list,current,rename}/SKILL.md)" ]'
ok "the start skill runs the check right after binding" 'grep -q "audit.sh\" \"\${CLAUDE_PROJECT_DIR}\" \"<feature>/<track>\" start" "$H/skills/start/SKILL.md"'
rm -rf "$A"
ok "the deep review runs in a separate, read-only context on Sonnet" 'grep -qx "context: fork" "$H/skills/audit/SKILL.md" && grep -qx "agent: keep:auditor" "$H/skills/audit/SKILL.md" && grep -qx "model: sonnet" "$H/agents/auditor.md" && grep -qx "tools: Read, Grep, Glob" "$H/agents/auditor.md"'
ok "a chat start or a fresh binding starts the review when it's due" 'grep -q "periodic review of this track is due" "$H/hooks/load.sh" && grep -q "audit.sh\" \"\${CLAUDE_PROJECT_DIR}\" \"<feature>/<track>\" due" "$H/skills/start/SKILL.md"'
ok "save and done no longer start it" '[ -z "$(grep -l "audit.sh.*due" "$H"/skills/{save,done}/SKILL.md)" ]'
ok "the handled result goes to a review file, with an Inbox pointer when it has items" '[ "$(grep -l "Nothing needs the user" "$H/hooks/load.sh" "$H/skills/start/SKILL.md" "$H/skills/audit/SKILL.md" | wc -l | tr -d " ")" = 3 ]'
ok "the start-of-chat text has no backticks, which bash would run as commands" '! grep -q "add \".*\`" "$H/hooks/load.sh"'

echo "--- skill commands"
ok "nothing refers to a custom keep folder anymore" '! grep -rq KEEP_FOLDER "$H"'
ok "skills run commands from the project root, not the working directory" '[ -z "$(grep -n "PWD" "$H"/skills/*/SKILL.md | grep -v "freshness.sh")" ]'
missing=""
for f in "$H"/skills/*/SKILL.md; do
  allow=$(grep -m1 "^allowed-tools:" "$f")
  for s in $(grep -o "scripts/[a-z-]*\.sh" "$f" | sort -u); do
    [[ "$allow" == *"Bash(bash \"\${CLAUDE_SKILL_DIR}/../../$s\" *)"* ]] || missing="$missing ${f#$H/}:$s"
  done
  if grep -q 'git -C "${CLAUDE_PROJECT_DIR}/.keep" commit' "$f"; then
    [[ "$allow" == *'Bash(git -C "${CLAUDE_PROJECT_DIR}/.keep" commit *)'* ]] || missing="$missing ${f#$H/}:commit"
  fi
done
ok "every skill pre-approves the keep scripts and .keep commits it runs${missing:+ (missing:$missing)}" '[ -z "$missing" ]'
ok "done marks the ticket done only after the commit is approved, and stops on a failed check" 'grep -q "Until then, the ticket stays open" "$H/skills/done/SKILL.md" && grep -q "If any of them fails, report it and stop" "$H/skills/done/SKILL.md"'
ok "next checks only the repos the ticket touches" 'grep -q "in each repo the ticket touches" "$H/skills/next/SKILL.md"'
ok "save lists what it recorded" 'grep -q "one line for each decision, Inbox line or rule you wrote" "$H/skills/save/SKILL.md"'
ok "the git offer comes only when .keep/ is created" 'grep -q "If \`\${CLAUDE_PROJECT_DIR}/.keep/\` doesn'"'"'t exist yet, also offer two separate choices" "$H/skills/start/SKILL.md"'
ok "new tracks don't load NOTES.md at every start" '! grep -q "^\*\*Read on start:\*\*" "$H/templates/CONTEXT.md"'
ok "next, done and save read the chat's binding before acting" '[ "$(grep -l "track-\${CLAUDE_SESSION_ID}" "$H"/skills/{next,done,save}/SKILL.md | wc -l | tr -d " ")" = 3 ]'
ok "next and done say they only apply in a chat bound to a track" '[ "$(grep -l "^description: In a chat bound to a keep track" "$H"/skills/{next,done}/SKILL.md | wc -l | tr -d " ")" = 2 ]'
ok "a ticket asked for right after binding still waits for approval" 'grep -q "write no code until the user approves" "$H/skills/start/SKILL.md"'
ok "closing asks about open items once" 'grep -q "Propose, in one list" "$H/skills/close/SKILL.md" && ! grep -q "For each open item, ask" "$H/skills/close/SKILL.md"'
ok "every skill command that touches .keep goes through the project root" '[ -z "$(grep -nE "\`(bash|git|grep)[^\`]*\.keep" "$H"/skills/*/SKILL.md | grep -v CLAUDE_PROJECT_DIR)" ]'

echo "---"
echo "passed $pass, failed $fail"
[ "$fail" = 0 ]
