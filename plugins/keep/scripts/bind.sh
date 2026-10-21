#!/usr/bin/env bash
# Usage: bind.sh <project root> <session id> <name | off>
# Binds a chat from the start skill, for when the agent starts a track the user agreed to, or unbinds it with
# "off". Typing /keep:start binds through the UserPromptSubmit hook instead, which also names the chat.
set -uo pipefail
. "$(dirname "$0")/common.sh"
root="${1:?project root}"
sid="${2:-}"
name="${3:-}"
keep=$(keep_dir "$root")
st="$keep/.state"
[[ "$sid" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "No valid session id: $sid" >&2; exit 1; }
[ -d "$keep" ] || { echo "No keep folder at $keep" >&2; exit 1; }
mkdir -p "$st"
[ -f "$st/.gitignore" ] || printf '*\n' > "$st/.gitignore"

# The hooks need jq and do nothing without it, so binding would look like it worked when nothing reloads or
# reminds.
note_jq() {
  command -v jq >/dev/null 2>&1 || echo "Note: jq isn't installed, so keep's hooks are off: no reload after /clear or a compaction, and no save reminders. Install jq to turn them on."
}

if [ "$name" = off ]; then
  unsaved=""
  [ -f "$st/dirty-$sid" ] && unsaved=" Its work since the last save wasn't saved there."
  title=$(unbind_chat "$keep" "$sid")
  if [ -z "$title" ]; then
    echo "This chat isn't bound to a track."
  else
    printf '%s' "$title" > "$st/title-$sid"
    echo "Unbound this chat from ${title% (unbound)}.$unsaved"
  fi
  note_jq
  exit 0
fi

before=$(cat "$st/track-$sid" 2>/dev/null || true)
target=$(bind_chat "$keep" "$sid" "$name")
case $? in
  1) echo "No single track matches \"$name\"." >&2; exit 1 ;;
  2) echo "This chat has unsaved work on $target. Save it there first with /keep:save, or unbind with /keep:start off if it doesn't belong there, then bind again." >&2; exit 2 ;;
esac
[ "$before" = "$target" ] || printf '%s' "$target" > "$st/title-$sid"
echo "Bound this chat to $target."
note_jq
