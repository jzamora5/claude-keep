#!/usr/bin/env bash
# freshness.sh <project root> <feature>/<track> [cwd]: what changed in the feature's repos since the track's
# STATE.md was last written, compared with the stamp the edit hook records. Pass the session's working
# directory as cwd so a Claude Code worktree session is checked in its worktree.
set -uo pipefail
. "$(dirname "$0")/common.sh"
root="${1:?project root}"
track="${2:?<feature>/<track>}"
keep=$(keep_dir "$root")
stamp=$(stamp_file "$keep" "$track")
worktree=$(worktree_root "$root" "${3:-}")

if [ ! -s "$stamp" ]; then
  echo "No git stamp yet: STATE.md hasn't been saved through keep in a git repo here, so its claims aren't checked against git."
  exit 0
fi

echo "Since STATE.md was last written ($(head -1 "$stamp" | cut -f6)):"
while IFS=$'\t' read -r repo hash branch dirty fingerprint _; do
  [ -n "$repo" ] || continue
  dir=$(repo_dir "$root" "$repo" "$worktree")
  label="$repo"
  [ "$repo" = "." ] && [ -n "$worktree" ] && label=". in worktree ${worktree##*/}"
  if ! git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
    echo "- $label: not a git repo here, not checked"
    continue
  fi
  if ! git -C "$dir" cat-file -e "$hash^{commit}" 2>/dev/null; then
    echo "- $label: the stamped commit ${hash:0:7} isn't in this checkout (rebased, or another clone)"
    continue
  fi
  now_branch=$(git -C "$dir" branch --show-current 2>/dev/null)
  changes=()
  if [ "$(git -C "$dir" rev-parse HEAD 2>/dev/null)" != "$hash" ]; then
    ahead=$(git -C "$dir" rev-list --count "$hash..HEAD" 2>/dev/null || echo 0)
    behind=$(git -C "$dir" rev-list --count "HEAD..$hash" 2>/dev/null || echo 0)
    [ "$ahead" -gt 0 ] && changes+=("$ahead new commit(s)")
    [ "$behind" -gt 0 ] && changes+=("moved back $behind commit(s)")
  fi
  [ "$now_branch" != "$branch" ] && changes+=("branch changed from ${branch:-detached} to ${now_branch:-detached}")
  if [ "$(changes_fingerprint "$dir")" != "$fingerprint" ] || [ -n "$(untracked_newer "$dir" "$stamp")" ]; then
    changes+=("uncommitted changes differ: $(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ') file(s) now, $dirty then")
  fi
  if [ "${#changes[@]}" -eq 0 ]; then
    echo "- $label (${now_branch:-detached}): no changes"
  else
    summary=$(printf '%s; ' "${changes[@]}")
    echo "- $label (${now_branch:-detached}): ${summary%; }"
    git -C "$dir" log --oneline -5 "$hash..HEAD" 2>/dev/null | sed 's/^/    /'
    [ "${ahead:-0}" -gt 5 ] && echo "    … and $((ahead - 5)) more"
  fi
  ahead=0
done < "$stamp"
echo "Recheck files before acting on what STATE.md says about them."
