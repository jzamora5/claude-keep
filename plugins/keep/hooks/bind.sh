#!/usr/bin/env bash
# UserPromptSubmit: "/keep:start <feature>/<track>" binds this chat to the track; "/keep:start off" unbinds it. A
# chat without a name of its own is named after its track; a chat the user named keeps its name, and keep
# remembers which track that name is on. Any other name, or a switch while the chat has unsaved work, is left to
# the start skill. A chat the start skill bound or unbound gets its new name at the next prompt.
. "$(dirname "$0")/lib.sh"

prompt=$(field .prompt)
name=$(chat_name "$keep" "$sid")
title=""
if [[ "$prompt" =~ ^/(keep:)?start[[:space:]]+([^[:space:]]+)([[:space:]]|$) ]]; then
  if [ "${BASH_REMATCH[2]}" = off ]; then
    title=$(unbind_chat "$keep" "$sid")
    [ -z "$name" ] || map_name "$keep" "$name" off
  elif target=$(bind_chat "$keep" "$sid" "${BASH_REMATCH[2]}"); then
    title="$target"
    [ -z "$name" ] || map_name "$keep" "$name" "$target"
  fi
fi
# keep never renames a chat the user named.
if [ -n "$name" ]; then
  rm -f "$st/title-$sid"
  exit 0
fi
# Only this hook and SessionStart can name a chat, so scripts/bind.sh leaves the name here for the next prompt.
[ -z "$title" ] && [ -s "$st/title-$sid" ] && title=$(cat "$st/title-$sid")
[ -n "$title" ] || exit 0

rm -f "$st/title-$sid"
jq -n --arg t "$title" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", sessionTitle: $t}}'
exit 0
