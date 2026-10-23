#!/usr/bin/env bash
# Stop: after edits or research, send the chat back to update the bound track's STATE.md, at most once per
# TRACKSIDE_SAVE_MINUTES (default 15; 0 asks after every working turn) since this chat last saved it. The edit hook
# asks first, before the reply; this catches a chat that didn't save then, so its reply is already written.
# This is the hook working as designed, so it answers with Stop hook feedback, not an error.
. "$(dirname "$0")/lib.sh"
[ "$(field .stop_hook_active)" = "true" ] && exit 0
[ -n "$binding" ] && [ -f "$st/dirty-$sid" ] || exit 0
# Claude Code blocks edits to the main checkout from a worktree session, and .trackside/ is there: asking for an
# update the chat can't make would only repeat every turn.
[ -z "$worktree" ] || exit 0
save_due "$st" "$sid" || exit 0

jq -n --arg p "$(rel "$keep/$binding")/STATE.md" '{
  hookSpecificOutput: {
    hookEventName: "Stop",
    additionalContext: ("Files changed or research was done since " + $p + " was last updated, and your reply is already written. Update its Current and Next step so a new chat could continue from it, marking Current lines [verified] or [assumed]; a line each is enough. Record any decision made since, with the options rejected and why, where FEATURE.md says decisions go, and add a line to another track'"'"'s Inbox when it affects that track. Do it without writing anything about it to the user. Then end your turn with no more text, or, if your reply asked the user something, with that question again in one line, so it stays the last thing they see.")
  }
}'
exit 0
