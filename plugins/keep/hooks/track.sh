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
    # doc-expert only reads the feature's own source docs, so asking it isn't new research.
    [[ "$(field .tool_input.subagent_type)" == *doc-expert ]] || touch "$st/dirty-$sid"
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
      "$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')" \
      "$(changes_fingerprint "$dir")" \
      "$(date -u +%Y-%m-%dT%H:%MZ)" >> "$tmp"
  done < <(repos_of "$keep/${binding%%/*}/FEATURE.md")
  mv "$tmp" "$stamp"
}

fp=$(field '.tool_input.file_path // .tool_input.notebook_path')
case "$fp" in
  "$tdir/STATE.md")
    rm -f "$st/dirty-$sid"
    write_stamp
    bash "$(dirname "$0")/../scripts/index.sh" "$root" 2>/dev/null ;;
  # Claude Code puts worktrees under .claude/worktrees/, so edits there are project edits.
  "$root"/.claude/worktrees/*) touch "$st/dirty-$sid" ;;
  "$keep"/*|"$root"/.claude/*|"") ;;
  *) touch "$st/dirty-$sid" ;;
esac
exit 0
