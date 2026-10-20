#!/usr/bin/env bash
# Stop: after edits or research since the bound track's STATE.md was last updated, send the chat back to update it.
. "$(dirname "$0")/lib.sh"
[ "$(field .stop_hook_active)" = "true" ] && exit 0
[ -n "$binding" ] && [ -f "$st/dirty-$sid" ] || exit 0

jq -n --arg p "$(rel "$keep/$binding")/STATE.md" '{
  decision: "block",
  reason: ("Files changed or research was done since " + $p + " was last updated. Update it so a new chat could continue from it: Current (mark lines [verified] or [assumed]), Next step, Tickets, Done log, Dead ends. A one-line Current update is enough if nothing else changed. If a decision affects another track, add a line to that track'"'"'s Inbox. Then finish.")
}'
exit 0
