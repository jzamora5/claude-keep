#!/usr/bin/env bash
# Usage: audit.sh <project root> <feature>/<track> start|save|due|reviewed
# keep's automatic check of one track. start prints every open issue; save prints only the ones not reported yet.
# Both skip the scan when the track's files haven't changed since the last one, so a clean or unchanged track
# costs almost nothing. due prints "due" when the track needs a deep review (the audit skill) and marks one as
# started; reviewed records that its result was handled.
set -uo pipefail
. "$(dirname "$0")/common.sh"
root=$(keep_root "${1:?project root}" "$PWD")
track="${2:?<feature>/<track>}"
mode="${3:?start, save or due}"
keep=$(keep_dir "$root")
f="${track%%/*}"
t="${track#*/}"
valid_name "$f" && valid_name "$t" && [ -f "$keep/$track/STATE.md" ] || exit 0
st="$keep/.state"
mkdir -p "$st"
[ -f "$st/.gitignore" ] || printf '*\n' > "$st/.gitignore"
feature="$keep/$f/FEATURE.md"
context="$keep/$track/CONTEXT.md"
state="$keep/$track/STATE.md"
notes="$keep/$track/NOTES.md"
cache="$st/audit-$f@$t"
told="$cache.told"

size() { if [ -f "$1" ]; then wc -c < "$1" | tr -d ' '; else echo 0; fi; }
# The script, the date and the source docs are part of the fingerprint: a keep update with different checks
# scans again, and so does a new day, since the Inbox check depends on the date, and a changed doc, since the
# ID check depends on it.
fingerprint() {
  { date +%Y-%m-%d; cat "$0" "$feature" "$context" "$state" "$notes" 2>/dev/null
    source_docs "$keep" "$f" | while IFS= read -r p; do cat "$root/$p"; done; } | cksum | tr ' ' '-'
}
# section <file> <heading>: the lines under "## <heading>".
section() { awk -v h="## $2" 'index($0, "## ") == 1 { c = (index($0, h) == 1); next } c' "$1" 2>/dev/null; }
epoch() { date -j -f %Y-%m-%d "$1" +%s 2>/dev/null || date -d "$1" +%s 2>/dev/null; }

# Limits match what a reload keeps whole; fixes aim well under them so a file doesn't flip back every save.
checks() {
  local s n missing big p path day now docs defined gone
  s=$(size "$state")
  [ "$s" -gt 5000 ] && printf 'state-size\tSTATE.md is %s bytes, over 5,000: move the oldest Done-log lines and settled Gotchas to NOTES.md until it is about 4,000.\n' "$s"
  s=$(size "$context")
  [ "$s" -gt 2600 ] && printf 'context-size\tCONTEXT.md is %s bytes, more than a reload keeps whole (2,600): move reference lists to NOTES.md.\n' "$s"
  s=$(size "$feature")
  [ "$s" -gt 2000 ] && printf 'feature-size\tFEATURE.md is %s bytes, over 2,000: move detail into the tracks or a source doc.\n' "$s"
  [ -n "$(section_line "$state" "Next step")" ] || printf 'next-step\tNext step is empty: write one concrete action (the file and function to touch, or the command to run).\n'
  n=$(section "$state" Current | grep -E '^[[:space:]]*[-*] ' | grep -v 'Ticket: none' | grep -vE ':[[:space:]]*$' | grep -cvE '\[(verified|assumed)\]')
  [ "$n" -gt 0 ] && printf 'unmarked\t%s Current line(s) are not marked [verified] or [assumed].\n' "$n"
  n=$(grep -E '^[[:space:]]*- \[ \] ' "$state" | grep -civ 'acceptance')
  [ "$n" -gt 0 ] && printf 'acceptance\t%s open ticket(s) in STATE.md have no acceptance check.\n' "$n"
  n=$(cat "$feature" "$context" "$state" 2>/dev/null | grep -v '<!--' | grep -cE "<[a-z][a-z ,:/.()'-]{12,}>")
  [ "$n" -gt 0 ] && printf 'placeholder\t%s template placeholder line(s) are left in FEATURE.md, CONTEXT.md or STATE.md: fill them in or delete them.\n' "$n"
  missing=""
  big=""
  while IFS='|' read -r p base kind; do
    [ -n "$p" ] || continue
    # Only real paths and keep's own files count: lists also name subagents and files inside a listed folder.
    case "$p" in *'<'*|*'*'*|*' '*|*DIGEST.md) continue ;; esac
    if [[ "$p" == */* ]]; then
      path="$root/$p"
    else
      case "$p" in NOTES.md|CONTEXT.md|STATE.md|FEATURE.md|DECISIONS.md) path="$base/$p" ;; *) continue ;; esac
    fi
    if [ ! -e "$path" ]; then
      missing="${missing:+$missing, }$p"
    elif [ "$kind" = start ] && [ -f "$path" ] && [ "$(size "$path")" -gt 15360 ]; then
      big="${big:+$big, }$p ($(( $(size "$path") / 1024 )) KB)"
    fi
  done < <(
    listed "$feature" "Source docs" | sed "s#\$#|$keep/$f|source#"
    listed "$feature" "Read on start" | sed "s#\$#|$keep/$f|start#"
    listed "$context" "Read on start" | sed "s#\$#|$keep/$track|start#"
  )
  [ -n "$missing" ] && printf 'missing-path\tFEATURE.md or CONTEXT.md names files that do not exist: %s.\n' "$missing"
  [ -n "$big" ] && printf 'big-read\tRead at every start but large: %s. The deep review can propose a short summary to load instead.\n' "$big"
  if [ -f "$notes" ]; then
    n=$(awk 'NR == FNR { if (length($0) >= 40) seen[$0] = 1; next } length($0) >= 40 && !/^#/ && !/<!--/ && ($0 in seen)' "$notes" "$state" | wc -l | tr -d ' ')
    [ "$n" -gt 0 ] && printf 'duplicate\t%s line(s) appear word for word in both STATE.md and NOTES.md: keep them in NOTES.md only.\n' "$n"
  fi
  # A cited ID counts as gone only when the docs define IDs like it and none of them mentions it, so ticket
  # keys and other IDs from outside the docs aren't flagged.
  docs=$(source_docs "$keep" "$f" | sed "s#^#$root/#")
  if [ -n "$docs" ]; then
    defined=$(printf '%s\n' "$docs" | while IFS= read -r p; do cat "$p"; done \
      | awk '(/^\|[ \t]*\**[A-Z]+-[0-9]+/ || /^#+[ \t]/) && match($0, /[A-Z]+-[0-9]+/) { s = substr($0, RSTART, RLENGTH); sub(/-.*/, "", s); print s }' | sort -u | tr '\n' ' ')
    gone=$(comm -23 <(ids_in "$state" "$context" | awk -v p=" $defined" '{ s = $0; sub(/-.*/, "", s); if (index(p, " " s " ")) print }') \
      <(printf '%s\n' "$docs" | while IFS= read -r p; do ids_in "$p"; done | sort -u) | head -10 | paste -sd ',' - | sed 's/,/, /g')
    [ -n "$gone" ] && printf 'id-missing\tSTATE.md or CONTEXT.md cites IDs no source doc mentions: %s. Check each with the doc-expert subagent: fix the line if the docs renamed or removed it, or ask the user whether to record it in the docs if it is new.\n' "$gone"
  fi
  now=$(date +%s)
  n=0
  while IFS= read -r day; do
    s=$(epoch "$day") || continue
    [ -n "$s" ] && [ $(( (now - s) / 86400 )) -gt 14 ] && n=$((n + 1))
  done < <(section "$state" Inbox | grep -v '<!--' | grep -oE '^[[:space:]]*[-*] [0-9]{4}-[0-9]{2}-[0-9]{2}' | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')
  [ "$n" -gt 0 ] && printf 'inbox-stale\t%s Inbox item(s) are older than two weeks: ask the user how to handle them.\n' "$n"
  return 0
}

if [ "$mode" = due ] || [ "$mode" = reviewed ]; then
  deep="$st/deep-$f@$t"
  now=$(date +%s)
  ns=$(size "$notes")
  fp=$(fingerprint)
  if [ "$mode" = reviewed ]; then
    printf '%s %s %s\n' "$now" "$ns" "$fp" > "$deep"
    rm -f "$deep.started"
    exit 0
  fi
  # A deep review is due when the notes grew by 10 KB since the last one, or two weeks passed with changes. It's
  # recorded only once its result is handled, so a result lost to /clear is retried; a review started in the
  # last hour is still running.
  [ -n "$(find "$deep.started" -mmin -60 2>/dev/null)" ] && exit 0
  if [ -f "$deep" ]; then
    read -r last lsize lfp < "$deep"
    [ $(( ns - ${lsize:-0} )) -ge 10240 ] || { [ $(( now - ${last:-0} )) -ge 1209600 ] && [ "$fp" != "$lfp" ]; } || exit 0
  elif [ "$ns" -lt 10240 ]; then
    printf '%s %s %s\n' "$now" "$ns" "$fp" > "$deep"
    exit 0
  fi
  touch "$deep.started"
  echo due
  exit 0
fi

fp=$(fingerprint)
if [ -f "$cache" ] && [ "$(head -1 "$cache")" = "$fp" ]; then
  [ "$mode" = save ] && exit 0
  issues=$(tail -n +2 "$cache")
else
  issues=$(checks)
  tmp=$(mktemp "$st/audit.XXXXXX") || exit 0
  { printf '%s\n' "$fp"; [ -z "$issues" ] || printf '%s\n' "$issues"; } > "$tmp" && mv "$tmp" "$cache"
fi
if [ -z "$issues" ]; then
  rm -f "$told"
  exit 0
fi
while IFS=$'\t' read -r key msg; do
  [ "$mode" = save ] && grep -qx "$key" "$told" 2>/dev/null && continue
  printf -- '- %s\n' "$msg"
done <<< "$issues"
printf '%s\n' "$issues" | cut -f1 > "$told"
