#!/usr/bin/env bash
# Usage: setup-git.sh <project root> ignore|history...
# ignore: keeps .keep/ out of the project's git through the local exclude file, so nothing shared with the team
# changes. history: gives .keep/ its own git history. Safe to run again.
set -uo pipefail
. "$(dirname "$0")/common.sh"
root="${1:?project root}"
shift
keep=$(keep_dir "$root")
[ -d "$keep" ] || { echo "No keep folder at $keep" >&2; exit 1; }
[ "$#" -gt 0 ] || { echo "Say what to set up: ignore, history or both." >&2; exit 1; }

for what in "$@"; do
  case "$what" in
    ignore)
      git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "The project isn't a git repo, so there's nothing to keep .keep/ out of."; continue; }
      git -C "$root" check-ignore -q .keep && continue
      ex=$(git -C "$root" rev-parse --git-path info/exclude)
      case "$ex" in /*) ;; *) ex="$root/$ex" ;; esac
      mkdir -p "$(dirname "$ex")"
      [ -s "$ex" ] && [ -n "$(tail -c1 "$ex")" ] && printf '\n' >> "$ex"
      printf '/%s.keep/\n' "$(git -C "$root" rev-parse --show-prefix)" >> "$ex"
      echo "The project's git now ignores .keep/ (in $ex, which isn't shared)." ;;
    history)
      [ -e "$keep/.git" ] && continue
      git -C "$keep" init -q || exit 1
      if git -C "$keep" add -A && git -C "$keep" commit -q -m "Start keep" 2>/dev/null; then
        echo ".keep/ has its own git history now."
      else
        echo ".keep/ has its own git repo now; its first commit failed, so commit it once git is set up."
      fi ;;
    *) echo "Unknown choice: $what (use ignore or history)" >&2; exit 1 ;;
  esac
done
