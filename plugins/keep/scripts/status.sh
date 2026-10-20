#!/usr/bin/env bash
# status.sh [project root]: each feature's tracks, with the first line of their Current section.
set -uo pipefail
. "$(dirname "$0")/common.sh"
root="${1:-$PWD}"
keep=$(keep_dir "$root")

if [ ! -d "$keep" ]; then
  echo "No keep folder at $keep yet."
  exit 0
fi
found=0
for f in $(list_features "$keep"); do
  for t in $(list_tracks "$keep" "$f"); do
    echo "- $f/$t: $(current_line "$keep/$f/$t/STATE.md")"
    found=1
  done
done
[ "$found" = 1 ] || echo "No tracks yet in $keep."
