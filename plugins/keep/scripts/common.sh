# Shared by the hooks and the helper scripts. Sourced, not run.

# keep_dir <project root>: the keep folder, ".keep" unless KEEP_FOLDER names another one.
keep_dir() {
  case "${KEEP_FOLDER:-.keep}" in
    /*) printf '%s' "$KEEP_FOLDER" ;;
    *) printf '%s/%s' "$1" "${KEEP_FOLDER:-.keep}" ;;
  esac
}

# Names are single path segments that don't start with a dot, so "../x" can't escape the keep folder.
valid_name() { [[ "$1" =~ ^[A-Za-z0-9_-][A-Za-z0-9._-]*$ ]]; }

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
