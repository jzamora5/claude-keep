# Shared by the hooks and the helper scripts. Sourced, not run. Functions that print paths use $root.

keep_dir() { printf '%s/.keep' "$1"; }

# keep_root <project dir> <working dir>: the folder whose .keep/ to use: the project dir when it has one, or
# else the nearest .keep/ at or above the working dir, so a chat that works in another folder than the one it
# started in still finds its keep folder.
keep_root() {
  local d="$2"
  if [ ! -d "$1/.keep" ]; then
    while [ -n "$d" ] && [ "$d" != / ]; do
      [ -d "$d/.keep" ] && { printf '%s' "$d"; return; }
      d=$(dirname "$d")
    done
  fi
  printf '%s' "$1"
}

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

# resolve_name <keep> <name>: the track a /keep:start name means, as <feature>/<track>. Only the full name counts:
# a bare track name doesn't say which feature it belongs to, and could mean another track once one is added.
resolve_name() {
  [[ "$2" == */* ]] || return 0
  local f="${2%%/*}" t="${2#*/}"
  valid_name "$f" && valid_name "$t" && [ -f "$1/$f/$t/STATE.md" ] && printf '%s/%s' "$f" "$t"
  return 0
}

# bind_chat <keep> <session id> <name>: binds the chat to the track and prints it. Returns 1 when the name
# matches no track or several. Returns 2, printing the current track, when the chat has unsaved work on another
# track: switching would leave that work to be saved into the wrong one.
bind_chat() {
  local target before
  target=$(resolve_name "$1" "$3")
  [ -n "$target" ] || return 1
  before=$(cat "$1/.state/track-$2" 2>/dev/null || true)
  if [ -n "$before" ] && [ "$before" != "$target" ] && [ -f "$1/.state/dirty-$2" ]; then
    printf '%s' "$before"
    return 2
  fi
  printf '%s\n' "$target" > "$1/.state/track-$2"
  printf '%s' "$target"
}

# unbind_chat <keep> <session id>: unbinds the chat, dropping its unsaved-work marker, and prints the chat's
# new name. "<feature>/<track> (unbound)" never reads as a track, so the chat isn't rebound by its name.
unbind_chat() {
  local before
  before=$(cat "$1/.state/track-$2" 2>/dev/null || true)
  [ -n "$before" ] || return 0
  rm -f "$1/.state/track-$2" "$1/.state/dirty-$2" "$1/.state/saved-$2"
  printf '%s (unbound)' "$before"
}

# A name the user gave a chat survives /clear, so it can stand in for the track name in the title: keep records
# each chat's own name as SessionStart reports it, remembers which track that name is on, and leaves the name be.

# keep_title <title>: true for a title keep set itself, a track name or one marked unbound.
keep_title() {
  [[ "$1" == *" (unbound)" ]] && return 0
  [[ "$1" == */* ]] && valid_name "${1%%/*}" && valid_name "${1#*/}"
}

# name_file <keep> <name>: where keep remembers the track a chat with this name is on.
name_file() { printf '%s/.state/named-%s' "$1" "$(printf '%s' "$2" | cksum | tr ' ' '-')"; }

# chat_name <keep> <session id>: the chat's own name, if the user gave it one.
chat_name() { cat "$1/.state/name-$2" 2>/dev/null || true; }

# map_name <keep> <name> <track>, named_track <keep> <name>. A chat the user unbound is mapped to "off", which
# no track can be named, so it isn't bound on its own again after /clear.
map_name() { [ -z "$2" ] || printf '%s\n' "$3" > "$(name_file "$1" "$2")"; }
named_track() { [ -z "$2" ] || cat "$(name_file "$1" "$2")" 2>/dev/null || true; }

# section_line <STATE.md> <heading>: the first entry under "## <heading>", skipping comments and blank lines.
section_line() {
  awk -v h="## $2" 'index($0, "## ") == 1 { c = (index($0, h) == 1); next }
       c && $0 !~ /^[[:space:]]*(<!--.*-->)?[[:space:]]*$/ { sub(/^[[:space:]]*[-*][[:space:]]*/, ""); print; exit }' "$1" 2>/dev/null | cut -c1-140
}

current_line() { section_line "$1" Current; }

# age_days <file>: whole days since the file last changed.
age_days() {
  local m
  m=$(date -r "$1" +%s 2>/dev/null) || { echo 0; return; }
  echo $(( ($(date +%s) - m) / 86400 ))
}

# goal_line <CONTEXT.md>: the text of its **Goal:** line, unless that's still the template's placeholder.
goal_line() {
  sed -n 's/^\*\*Goal:\*\*[[:space:]]*//p' "$1" 2>/dev/null | head -1 | grep -v '^<' | cut -c1-140
}

# track_rows <keep>: one line per track: feature, track, current work (or its goal when nothing is in flight,
# so a new chat can still tell what the track is for), last update, days since.
track_rows() {
  local f t s work goal
  for f in $(list_features "$1"); do
    for t in $(list_tracks "$1" "$f"); do
      s="$1/$f/$t/STATE.md"
      work=$(current_line "$s" | tr '\t' ' ')
      if [[ "$(printf '%s' "$work" | tr 'A-Z' 'a-z')" =~ ^((ticket:[[:space:]]*)?none([^a-z]|$)|$) ]]; then
        goal=$(goal_line "$1/$f/$t/CONTEXT.md" | tr '\t' ' ')
        [ -n "$goal" ] && work="Goal: $goal"
      fi
      printf '%s\t%s\t%s\t%s\t%s\n' "$f" "$t" "$work" "$(date -r "$s" +%Y-%m-%d 2>/dev/null)" "$(age_days "$s")"
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

# repo_status <dir>: git status of a repo, leaving out keep's own folder, which isn't project work even when
# it sits inside the project's repo.
repo_status() { git -C "$1" status --porcelain -- ':(exclude).keep' 2>/dev/null; }

# changes_fingerprint <dir>: changes when tracked changes or the list of untracked files changes, not only
# the number of files. Untracked contents aren't hashed, so a large untracked file can't slow the hooks;
# untracked_newer covers rewrites of those.
changes_fingerprint() {
  { repo_status "$1"; git -C "$1" diff HEAD -- ':(exclude).keep' 2>/dev/null; } | git hash-object --stdin 2>/dev/null
}

# untracked_newer <dir> <file>: the first untracked file modified after <file>, if any.
untracked_newer() {
  git -C "$1" ls-files --others --exclude-standard -z -- ':(exclude).keep' 2>/dev/null \
    | (cd "$1" && xargs -0 sh -c '[ "$#" -gt 0 ] || exit 0; find "$@" -prune -newer "$0" -print' "$2" 2>/dev/null) | head -1
}

# lines_within <bytes>: copy whole lines from stdin while they fit, so a cut never splits a character.
lines_within() { LC_ALL=C awk -v b="$1" '{ n += length($0) + 1; if (n > b) exit; print }'; }

bytes() { printf '%s' "$1" | wc -c | tr -d ' '; }
