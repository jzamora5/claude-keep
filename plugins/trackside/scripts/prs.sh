#!/usr/bin/env bash
# prs.sh <project root> <feature>/<track>: the state of each pull request the track's STATE.md names as
# <repo>#<number>, where <repo> is a folder on FEATURE.md's Repos line, skipping lines that already say it merged or
# closed. Read-only, through gh in that repo's folder, and at most 10 per run; prints nothing for a pull request gh
# can't read, or at all without gh.
set -uo pipefail
. "$(dirname "$0")/common.sh"
root=$(keep_root "${1:?project root}" "$PWD")
track="${2:?<feature>/<track>}"
keep=$(keep_dir "$root")
state="$keep/$track/STATE.md"
[ -f "$state" ] && command -v gh >/dev/null 2>&1 || exit 0

n=0
while IFS= read -r r; do
  [ "$r" != "." ] || continue
  dir=$(repo_dir "$root" "$r" "")
  git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 || continue
  for num in $(grep -viE 'merged|closed' "$state" | grep -oE "(^|[^A-Za-z0-9._/-])${r//./\\.} ?#[0-9]+" | grep -oE '[0-9]+$' | sort -un); do
    [ "$n" -lt 10 ] || break 2
    n=$((n + 1))
    s=$(cd "$dir" && gh pr view "$num" --json state,mergedAt --jq '.state + " " + ((.mergedAt // "")[0:10])' 2>/dev/null) || continue
    [ -n "$s" ] && printf '%s#%s: %s\n' "$r" "$num" "$(printf '%s' "$s" | tr 'A-Z' 'a-z' | sed 's/ *$//')"
  done
done < <(repos_of "$keep/${track%%/*}/FEATURE.md")
exit 0
