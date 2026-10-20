#!/usr/bin/env bash
# SessionStart (startup|resume|clear|compact|fork): reload the bound track (FEATURE.md, the track's CONTEXT.md
# and STATE.md) and report what changed in the feature's repos since STATE.md was written. An unbound chat
# gets the list of tracks instead. Compactions are counted, and after COMPACT_LIMIT (default 2) the agent
# is asked to save and suggest a fresh chat.
. "$(dirname "$0")/lib.sh"
here="$(dirname "$0")"
src=$(field .source)
title=$(field .session_title)
limit="${COMPACT_LIMIT:-2}"

# Hook output over 10,000 characters reaches Claude only as a 2,000-character preview. Everything here shares
# one budget, counted in bytes (never fewer than characters), and cuts fall at line ends so no character
# is split. A file that doesn't fit loses whole sections, which are named.
budget=9300
out=""
add() { out+="$1"$'\n'; }

# emit <title> <file> <budget> [sections that always load...]
emit() {
  local title="$1" f="$2" b="$3" i n used size pre left want name s e
  local -a names starts ends inc
  shift 3
  add ""
  if [ ! -f "$f" ]; then add "=== $title: missing ($(rel "$f")) ==="; return; fi
  add "=== $title ($(rel "$f")) ==="
  if [ "$(wc -c < "$f" | tr -d ' ')" -le "$b" ]; then add "$(cat "$f")"; return; fi

  names=(); starts=(); ends=(); inc=()
  while IFS=$'\t' read -r name s e; do
    [ -n "$name" ] || continue
    names+=("$name"); starts+=("$s"); ends+=("$e"); inc+=(0)
  done < <(awk '/^## /{ if (n) print name "\t" s "\t" NR-1; name = substr($0, 4); s = NR; n = 1 }
                END { if (n) print name "\t" s "\t" NR }' "$f")
  n=${#names[@]}
  if [ "$n" -eq 0 ]; then
    add "$(lines_within "$b" < "$f")"
    add "[Cut to stay under the hook output limit: read $(rel "$f") for the rest.]"
    return
  fi

  pre=""
  [ "${starts[0]}" -gt 1 ] && pre=$(sed -n "1,$(( starts[0] - 1 ))p" "$f")
  used=$(bytes "$pre")
  for want in "$@"; do
    for ((i = 0; i < n; i++)); do
      [ "${names[$i]}" = "$want" ] || continue
      size=$(sed -n "${starts[$i]},${ends[$i]}p" "$f" | wc -c)
      inc[$i]=1
      used=$(( used + size ))
    done
  done
  for ((i = 0; i < n; i++)); do
    [ "${inc[$i]}" = 1 ] && continue
    size=$(sed -n "${starts[$i]},${ends[$i]}p" "$f" | wc -c)
    if [ $(( used + size )) -le "$b" ]; then
      inc[$i]=1
      used=$(( used + size ))
    fi
  done

  [ -n "$pre" ] && add "$pre"
  left=""
  for ((i = 0; i < n; i++)); do
    if [ "${inc[$i]}" = 1 ]; then
      add "$(sed -n "${starts[$i]},${ends[$i]}p" "$f")"
    else
      left="${left:+$left, }${names[$i]}"
    fi
  done
  [ -n "$left" ] && add "[Not loaded, to stay under the hook output limit: $left. Read $(rel "$f") for them.]"
}

# The bind hook names the chat "<feature>/<track>", so a session that starts without a binding
# (after /clear or a resume) can be rebound by its title.
if [ -z "$binding" ] && [[ "$title" == */* ]] && valid_name "${title%%/*}" && valid_name "${title#*/}" \
   && [ -f "$keep/$title/STATE.md" ]; then
  binding="$title"
  printf '%s\n' "$binding" > "$st/track-$sid"
fi
[ "$src" = "clear" ] && rm -f "$st/compactions-$sid"

# Housekeeping: runtime files of old sessions only pile up, and a resumed chat rebinds from its title.
# Stamps are kept: they matter most after a long pause, and closing a track removes its own.
find "$st" -type f ! -name .gitignore ! -name 'stamp-*' -mtime +"${KEEP_STATE_DAYS:-30}" -exec rm -f {} + 2>/dev/null
[ -n "$binding" ] && printf '%s\n' "$binding" > "$st/track-$sid"
bash "$here/../scripts/index.sh" "$root" 2>/dev/null

if [ -z "$binding" ] || [ ! -f "$keep/$binding/STATE.md" ]; then
  add "No keep track is bound to this chat. The user binds one with /keep:start <feature>/<track>."
  list=$(bash "$here/../scripts/status.sh" "$root" 2>/dev/null)
  if [ -n "$list" ]; then
    add "Tracks and their current work:"
    add "$list"
  fi
  printf '%s' "$out" | lines_within "$budget"
  exit 0
fi

fdir="$keep/${binding%%/*}"
tdir="$keep/$binding"
add "Active track: $binding. Its files: $(rel "$fdir")/FEATURE.md, plus CONTEXT.md, STATE.md and NOTES.md in $(rel "$tdir")/."
add "STATE.md is the handoff for the next chat and must stay current."

if [ "$src" = "compact" ]; then
  c=$(cat "$st/compactions-$sid" 2>/dev/null || true)
  [[ "$c" =~ ^[0-9]+$ ]] || c=0
  n=$(( c + 1 ))
  echo "$n" > "$st/compactions-$sid"
  add "This chat has been compacted $n time(s); the files below are authoritative over the summary."
  add "Re-read the files FEATURE.md and CONTEXT.md list under \"Read on start\"; the summary may have dropped them."
  if [ "$n" -ge "$limit" ]; then
    add "After $limit compactions: finish the current small step, run /keep:save, then tell the user to /clear, or to start a new chat with /keep:start $binding."
  fi
fi

add ""
add "$(bash "$here/../scripts/freshness.sh" "$root" "$binding" "$(field .cwd)" 2>/dev/null | head -n 25)"
emit "FEATURE.md" "$fdir/FEATURE.md" 2000
emit "CONTEXT.md" "$tdir/CONTEXT.md" 1500
emit "STATE.md" "$tdir/STATE.md" $(( budget - $(bytes "$out") - 200 )) "Inbox" "Current" "Next step"

if [ "$(bytes "$out")" -gt 9800 ]; then
  out="$(printf '%s' "$out" | lines_within 9600)"$'\n'"[Cut to stay under the hook output limit: read $(rel "$tdir")/STATE.md in full.]"
fi
printf '%s' "$out"
exit 0
