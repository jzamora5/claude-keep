# Shared by the hooks and the helper scripts. Sourced, not run. Functions that print paths use $root.

keep_dir() { printf '%s/.keep' "$1"; }

rel() { printf '%s' "${1#"$root"/}"; }

# Names are single path segments starting with a letter or digit, so "../x" can't escape the keep folder
# and keep's own folders (".state", "_archive") never count as features or tracks.
valid_name() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; }

list_features() {
  local d
  for d in "$1"/*/; do
    [ -d "$d" ] || continue
    valid_name "$(basename "$d")" && basename "$d"
  done
}

# list_tracks <keep> <feature>: a folder counts as a track only once it holds a STATE.md.
list_tracks() {
  local d
  for d in "$1/$2"/*/; do
    [ -f "$d/STATE.md" ] || continue
    valid_name "$(basename "$d")" && basename "$d"
  done
}

# resolve_target <keep> <name>: the track a one-word /keep:start means: a feature's only track, or else the
# one track anywhere with that name. Prints nothing when the name matches no track or several.
resolve_target() {
  local tracks f hits=""
  valid_name "$2" || return 0
  if [ -d "$1/$2" ]; then
    tracks=$(list_tracks "$1" "$2")
    [ -n "$tracks" ] && [ "$(printf '%s\n' "$tracks" | wc -l | tr -d ' ')" = 1 ] && printf '%s/%s' "$2" "$tracks"
    return 0
  fi
  for f in $(list_features "$1"); do
    [ -f "$1/$f/$2/STATE.md" ] && hits="$hits $f/$2"
  done
  set -- $hits
  [ "$#" = 1 ] && printf '%s' "$1"
  return 0
}

# start_arg <keep> <feature> <track>: the shortest /keep:start argument that still names this track.
start_arg() {
  local best="$2/$3"
  [ "$(resolve_target "$1" "$2")" = "$2/$3" ] && best="$2"
  if [ "$(resolve_target "$1" "$3")" = "$2/$3" ] && [ "${#3}" -le "${#best}" ]; then best="$3"; fi
  printf '%s' "$best"
}

# current_line <STATE.md>: the first entry under "## Current", skipping comments and blank lines.
current_line() {
  awk '/^## /{ c = ($0 ~ /^## Current/); next }
       c && $0 !~ /^[[:space:]]*(<!--.*-->)?[[:space:]]*$/ { sub(/^[[:space:]]*[-*][[:space:]]*/, ""); print; exit }' "$1" 2>/dev/null | cut -c1-140
}

# age_days <file>: whole days since the file last changed.
age_days() {
  local m
  m=$(date -r "$1" +%s 2>/dev/null) || { echo 0; return; }
  echo $(( ($(date +%s) - m) / 86400 ))
}

# track_rows <keep>: one line per track: feature, track, current work, last update, days since.
track_rows() {
  local f t s
  for f in $(list_features "$1"); do
    for t in $(list_tracks "$1" "$f"); do
      s="$1/$f/$t/STATE.md"
      printf '%s\t%s\t%s\t%s\t%s\n' "$f" "$t" "$(current_line "$s" | tr '\t' ' ')" \
        "$(date -r "$s" +%Y-%m-%d 2>/dev/null)" "$(age_days "$s")"
    done
  done
}

# The stamp is local runtime state: it describes this machine's checkouts, so it stays out of git.
stamp_file() { printf '%s/.state/stamp-%s@%s' "$1" "${2%%/*}" "${2#*/}"; }

# worktree_root <root> <cwd>: the Claude Code worktree (under .claude/worktrees/) a session works in, if any.
worktree_root() {
  local rest
  case "$2" in
    "$1"/.claude/worktrees/?*)
      rest="${2#"$1"/.claude/worktrees/}"
      printf '%s/.claude/worktrees/%s' "$1" "${rest%%/*}" ;;
  esac
}

# repo_dir <root> <repo> <worktree>: where to read a repo listed in FEATURE.md. In a worktree session the
# project's own repo (".") is read in the worktree, since that's the checkout being edited.
repo_dir() {
  if [ "$2" = "." ]; then printf '%s' "${3:-$1}"; else printf '%s/%s' "$1" "$2"; fi
}

# changes_fingerprint <dir>: changes when tracked changes or the list of untracked files changes, not only
# the number of files. Untracked contents aren't hashed, so a large untracked file can't slow the hooks;
# untracked_newer covers rewrites of those.
changes_fingerprint() {
  { git -C "$1" status --porcelain 2>/dev/null; git -C "$1" diff HEAD 2>/dev/null; } | git hash-object --stdin 2>/dev/null
}

# untracked_newer <dir> <file>: the first untracked file modified after <file>, if any.
untracked_newer() {
  git -C "$1" ls-files --others --exclude-standard -z 2>/dev/null \
    | (cd "$1" && xargs -0 sh -c '[ "$#" -gt 0 ] || exit 0; find "$@" -prune -newer "$0" -print' "$2" 2>/dev/null) | head -1
}

# lines_within <bytes>: copy whole lines from stdin while they fit, so a cut never splits a character.
lines_within() { LC_ALL=C awk -v b="$1" '{ n += length($0) + 1; if (n > b) exit; print }'; }

bytes() { printf '%s' "$1" | wc -c | tr -d ' '; }
