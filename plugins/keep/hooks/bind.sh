#!/usr/bin/env bash
# UserPromptSubmit: "/keep:start <feature>/<track>", or a single name that matches exactly one track, binds this
# chat to the track and names the chat after it; "/keep:start off" unbinds it. A name that matches several
# tracks, or a switch while the chat has unsaved work, is left to the start skill. A chat the start skill bound
# or unbound gets its name at the next prompt.
. "$(dirname "$0")/lib.sh"

prompt=$(field .prompt)
title=""
if [[ "$prompt" =~ ^/(keep:)?start[[:space:]]+([^[:space:]]+)([[:space:]]|$) ]]; then
  if [ "${BASH_REMATCH[2]}" = off ]; then
    title=$(unbind_chat "$keep" "$sid")
  else
    title=$(bind_chat "$keep" "$sid" "${BASH_REMATCH[2]}") || title=""
  fi
fi
# Only this hook and SessionStart can name a chat, so scripts/bind.sh leaves the name here for the next prompt.
[ -z "$title" ] && [ -s "$st/title-$sid" ] && title=$(cat "$st/title-$sid")
[ -n "$title" ] || exit 0

rm -f "$st/title-$sid"
jq -n --arg t "$title" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", sessionTitle: $t}}'
exit 0
