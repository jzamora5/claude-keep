#!/usr/bin/env bash
# freshness.sh <project root> <track folder>: what changed in the feature's repos since the track's STATE.md
# was last written, read from the stamp the edit hook records (repo, commit, branch, uncommitted files, time).
set -uo pipefail
root="${1:-$PWD}"
tdir="$2"
case "$tdir" in /*) ;; *) tdir="$root/$tdir" ;; esac
stamp="$tdir/.stamp"

if [ ! -s "$stamp" ]; then
  echo "No git stamp yet: STATE.md hasn't been saved through keep in a git repo, so its claims aren't checked against git."
  exit 0
fi

echo "Since STATE.md was last written ($(head -1 "$stamp" | cut -f5)):"
while IFS=$'\t' read -r repo hash branch dirty _; do
  [ -n "$repo" ] || continue
  dir="$root/$repo"; [ "$repo" = "." ] && dir="$root"
  if ! git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
    echo "- $repo: not a git repo here, not checked"
    continue
  fi
  now_branch=$(git -C "$dir" branch --show-current 2>/dev/null)
  now_dirty=$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if ! git -C "$dir" cat-file -e "$hash^{commit}" 2>/dev/null; then
    echo "- $repo: the stamped commit ${hash:0:7} isn't in this checkout (rebased, or another clone)"
    continue
  fi
  count=$(git -C "$dir" rev-list --count "$hash..HEAD" 2>/dev/null || echo 0)
  note=""
  [ "$now_branch" != "$branch" ] && note=", branch changed from ${branch:-detached} to ${now_branch:-detached}"
  if [ "$count" = 0 ] && [ "$now_dirty" = "$dirty" ] && [ -z "$note" ]; then
    echo "- $repo (${now_branch:-detached}): no changes"
  else
    echo "- $repo (${now_branch:-detached}): $count new commit(s), $now_dirty uncommitted file(s), was $dirty$note"
    git -C "$dir" log --oneline -5 "$hash..HEAD" 2>/dev/null | sed 's/^/    /'
    [ "$count" -gt 5 ] && echo "    … and $((count - 5)) more"
  fi
done < "$stamp"
echo "Recheck files before acting on what STATE.md says about them."
