#!/usr/bin/env bash
# Usage: current.sh <project root> <session id>
# Prints the track this chat is bound to, with its current work, next step and start command, or says the chat
# isn't bound and lists the tracks.
set -uo pipefail
. "$(dirname "$0")/common.sh"
root=$(keep_root "${1:?project root}" "$PWD")
sid="${2:-}"
keep=$(keep_dir "$root")
[[ "$sid" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "No valid session id: $sid" >&2; exit 1; }
[ -d "$keep" ] || { echo "No keep folder at $keep, so this chat isn't on a track."; exit 0; }

b=$(cat "$keep/.state/track-$sid" 2>/dev/null || true)
if [ -z "$b" ] || [ ! -f "$keep/$b/STATE.md" ]; then
  echo "This chat isn't bound to a track."
  bash "$(dirname "$0")/status.sh" "$root"
  exit 0
fi
s="$keep/$b/STATE.md"
echo "This chat is on $b. A new chat starts it with /keep:start $b."
echo "Current: $(current_line "$s" | grep . || echo "nothing written yet")"
echo "Next step: $(section_line "$s" "Next step" | grep . || echo "none written yet")"
