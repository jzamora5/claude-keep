#!/usr/bin/env bash
# status.sh [project root]: each feature's tracks with their current work and the command that starts each,
# flagging idle ones.
set -uo pipefail
. "$(dirname "$0")/common.sh"
root=$(keep_root "${1:-$PWD}" "$PWD")
keep=$(keep_dir "$root")
idle="${TRACKSIDE_IDLE_DAYS:-14}"

if [ ! -d "$keep" ]; then
  echo "No trackside folder at $keep yet."
  exit 0
fi
rows=$(track_rows "$keep")
if [ -z "$rows" ]; then
  echo "No tracks yet in $keep."
  exit 0
fi
while IFS=$'\t' read -r f t cur _ days; do
  kind=""
  starts_clean "$keep" "$f/$t" && kind=" (each item starts clean)"
  line="- $f/$t$kind: ${cur:-no current work} (start: /trackside:start $f/$t)"
  [ "$days" -ge "$idle" ] && line="$line (idle $days days; close it with /trackside:close $f/$t)"
  echo "$line"
done <<<"$rows"
