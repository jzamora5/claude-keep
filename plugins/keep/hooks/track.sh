#!/usr/bin/env bash
# PostToolUse (Edit|Write|NotebookEdit|WebFetch|WebSearch|Agent): edits to project files and research mark
# the chat "dirty". Editing the bound track's STATE.md clears that and stamps each of the feature's repos
# with its current commit, so the next chat can see what changed since.
. "$(dirname "$0")/lib.sh"
[ -n "$binding" ] || exit 0
tdir="$keep/$binding"

case "$(field .tool_name)" in
  WebFetch|WebSearch) touch "$st/dirty-$sid"; exit 0 ;;
  Agent)
    # keep's doc-expert and auditor only read the feature's own files, so asking them isn't new research.
    case "$(field .tool_input.subagent_type)" in
      keep:doc-expert|doc-expert|keep:auditor|auditor) ;;
      *) touch "$st/dirty-$sid" ;;
    esac
    exit 0 ;;
esac

# repos_of <FEATURE.md>: the folders on its "Repos:" line, or "." for the project root.
repos_of() {
  local line
  line=$(grep -m1 -iE '^[-*[:space:]]*(\*\*)?repos:' "$1" 2>/dev/null \
    | sed -E 's/^[^:]*:[[:space:]]*(\*\*)?[[:space:]]*//; s/`//g')
  [ -n "$line" ] || line="."
  printf '%s\n' "$line" | tr ',' '\n' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s#/$##' | grep -v '^$'
}

write_stamp() {
  local stamp tmp r dir
  stamp=$(stamp_file "$keep" "$binding")
  tmp=$(mktemp "$st/stamp.XXXXXX") || return 0
  while IFS= read -r r; do
    dir=$(repo_dir "$root" "$r" "$worktree")
    git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 || continue
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$r" \
      "$(git -C "$dir" rev-parse HEAD 2>/dev/null)" \
      "$(git -C "$dir" branch --show-current 2>/dev/null)" \
      "$(repo_status "$dir" | wc -l | tr -d ' ')" \
      "$(changes_fingerprint "$dir")" \
      "$(date -u +%Y-%m-%dT%H:%MZ)" >> "$tmp"
  done < <(repos_of "$keep/${binding%%/*}/FEATURE.md")
  mv "$tmp" "$stamp"
}

fp=$(field '.tool_input.file_path // .tool_input.notebook_path')
case "$fp" in
  "$tdir/STATE.md")
    rm -f "$st/dirty-$sid"
    touch "$st/saved-$sid"
    write_stamp
    bash "$(dirname "$0")/../scripts/index.sh" "$root" 2>/dev/null
    issues=$(bash "$(dirname "$0")/../scripts/audit.sh" "$root" "$binding" save 2>/dev/null)
    [ -z "$issues" ] || jq -n --arg c "keep's check of $binding after this save:
$issues
Fix the ones that only move or de-duplicate text, or fill in what's missing, in this turn. Anything that drops or rewords content, ask the user about at the next natural pause." \
      '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}' ;;
  # Claude Code puts worktrees under .claude/worktrees/, so edits there are project edits.
  "$root"/.claude/worktrees/*) touch "$st/dirty-$sid" ;;
  # Claude's own files (settings, memory, plans) aren't project work.
  "$keep"/*|"$root"/.claude/*|"${HOME:-/nonexistent}"/.claude/*|"") ;;
  "$root"/*) touch "$st/dirty-$sid" ;;
esac
exit 0
