# Shared by the hooks and the helper scripts. Sourced, not run.

# keep_dir <project root>: the keep folder, ".keep" unless KEEP_FOLDER names another one.
keep_dir() {
  case "${KEEP_FOLDER:-.keep}" in
    /*) printf '%s' "$KEEP_FOLDER" ;;
    *) printf '%s/%s' "$1" "${KEEP_FOLDER:-.keep}" ;;
  esac
}

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
