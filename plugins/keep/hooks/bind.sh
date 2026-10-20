#!/usr/bin/env bash
# UserPromptSubmit: "/keep:start <feature>/<track>" binds this chat to the track and names the chat after it.
. "$(dirname "$0")/lib.sh"

prompt=$(field .prompt)
[[ "$prompt" =~ ^/(keep:)?start[[:space:]]+([^[:space:]/]+)(/([^[:space:]/]+))?([[:space:]]|$) ]] || exit 0
feature="${BASH_REMATCH[2]}"
track="${BASH_REMATCH[4]}"
valid_name "$feature" || exit 0

if [ -z "$track" ]; then
  # A feature with exactly one track binds to it; with several, the start skill asks which one.
  tracks=$(list_tracks "$keep" "$feature")
  [ -n "$tracks" ] && [ "$(printf '%s\n' "$tracks" | wc -l | tr -d ' ')" = 1 ] || exit 0
  track="$tracks"
fi
valid_name "$track" || exit 0
[ -f "$keep/$feature/$track/STATE.md" ] || exit 0

printf '%s\n' "$feature/$track" > "$st/track-$sid"
jq -n --arg t "$feature/$track" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", sessionTitle: $t}}'
exit 0
