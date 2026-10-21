#!/usr/bin/env bash
# Stop: after edits or research, send the chat back to update the bound track's STATE.md, at most once per
# KEEP_SAVE_MINUTES (default 15; 0 asks after every working turn) since this chat last saved it. This is the
# hook working as designed, so it answers with Stop hook feedback, not an error.
. "$(dirname "$0")/lib.sh"
[ "$(field .stop_hook_active)" = "true" ] && exit 0
[ -n "$binding" ] && [ -f "$st/dirty-$sid" ] || exit 0
# Claude Code blocks edits to the main checkout from a worktree session, and .keep/ is there: asking for an
# update the chat can't make would only repeat every turn.
[ -z "$worktree" ] || exit 0
mins="${KEEP_SAVE_MINUTES:-15}"
[[ "$mins" =~ ^[0-9]+$ ]] || mins=15
# The clock is this chat's own last save: another chat editing the same STATE.md, for example to add an
# Inbox line, says nothing about this chat's work.
saved="$st/saved-$sid"
[ "$mins" = 0 ] || [ ! -f "$saved" ] || [ -n "$(find "$saved" -mmin +"$mins" 2>/dev/null)" ] || exit 0

jq -n --arg p "$(rel "$keep/$binding")/STATE.md" '{
  hookSpecificOutput: {
    hookEventName: "Stop",
    additionalContext: ("Files changed or research was done since " + $p + " was last updated. Update its Current and Next step so a new chat could continue from it, marking Current lines [verified] or [assumed]; a line each is enough. Record any decision made since, with the options rejected and why, where FEATURE.md says decisions go, and add a line to another track'"'"'s Inbox when it affects that track. Then finish.")
  }
}'
exit 0
