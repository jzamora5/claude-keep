#!/usr/bin/env bash
# UserPromptSubmit: "/keep:start <feature>/<track>", or a single name that matches exactly one track, binds this
# chat to the track and names the chat after it. When a name matches several, the start skill asks which one.
. "$(dirname "$0")/lib.sh"

prompt=$(field .prompt)
[[ "$prompt" =~ ^/(keep:)?start[[:space:]]+([^[:space:]/]+)(/([^[:space:]/]+))?([[:space:]]|$) ]] || exit 0
feature="${BASH_REMATCH[2]}"
track="${BASH_REMATCH[4]}"

if [ -z "$track" ]; then
  target=$(resolve_target "$keep" "$feature")
  [ -n "$target" ] || exit 0
  feature="${target%%/*}"
  track="${target#*/}"
fi
valid_name "$feature" && valid_name "$track" || exit 0
[ -f "$keep/$feature/$track/STATE.md" ] || exit 0

printf '%s\n' "$feature/$track" > "$st/track-$sid"
jq -n --arg t "$feature/$track" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", sessionTitle: $t}}'
exit 0
