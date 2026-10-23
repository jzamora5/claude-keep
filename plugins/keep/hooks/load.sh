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

# A session that starts without a binding (after /clear) is rebound by its title: a chat keep named after its
# track by that name, and a chat the user named through the track keep remembered for the name.
if [ -z "$binding" ] && [[ "$title" == */* ]] && valid_name "${title%%/*}" && valid_name "${title#*/}" \
   && [ -f "$keep/$title/STATE.md" ]; then
  binding="$title"
  printf '%s\n' "$binding" > "$st/track-$sid"
fi
if [ -n "$title" ] && ! keep_title "$title"; then
  printf '%s\n' "$title" > "$st/name-$sid"
  if [ -z "$binding" ]; then
    named=$(named_track "$keep" "$title")
    [ -n "$named" ] && [ -f "$keep/$named/STATE.md" ] && binding="$named"
  fi
  [ -n "$binding" ] && [ -f "$keep/$binding/STATE.md" ] && map_name "$keep" "$title" "$binding"
else
  rm -f "$st/name-$sid"
fi
[ "$src" = "clear" ] && rm -f "$st/compactions-$sid"

# Housekeeping: runtime files of old sessions only pile up, and a resumed chat rebinds from its title.
# Stamps are kept: they matter most after a long pause, and closing a track removes its own.
find "$st" -type f ! -name .gitignore ! -name 'stamp-*' -mtime +"${KEEP_STATE_DAYS:-30}" -exec rm -f {} + 2>/dev/null
[ -n "$binding" ] && printf '%s\n' "$binding" > "$st/track-$sid"
bash "$here/../scripts/index.sh" "$root" 2>/dev/null

if [ -z "$binding" ] || [ ! -f "$keep/$binding/STATE.md" ]; then
  add "No keep track is bound to this chat. The user may call a track a workspace."
  list=$(bash "$here/../scripts/status.sh" "$root" 2>/dev/null)
  if [[ "$list" == "- "* ]]; then
    add "Tracks, their current work or goal, and how to start each:"
    add "$list"
  fi
  add "The first time a message of the user starts work (a change, research or a ticket, not a quick question), ask once whether to keep that work in a track: name the matching track, list the candidates if it could be more than one, or offer to create a track if none matches. Act only after the user agrees, by running the keep start skill (/keep:start) with the track's full name, <feature>/<track>, or with no name to create one, and then carry on with what they asked. Otherwise just answer."
  printf '%s' "$out" | lines_within "$budget"
  exit 0
fi

fdir="$keep/${binding%%/*}"
tdir="$keep/$binding"
add "Active track: $binding (a new chat starts it with /keep:start $binding). Its files: $(rel "$fdir")/FEATURE.md, plus CONTEXT.md, STATE.md and NOTES.md in $(rel "$tdir")/."
add "The user may call a track a workspace; /keep:current shows this one."
add "STATE.md is the handoff for the next chat and must stay current. Record each decision as soon as it's made, with the options rejected and why, where FEATURE.md says decisions go."
if [ -n "$worktree" ]; then
  add "This chat runs in a Claude Code worktree, and Claude Code blocks edits to the main checkout, where $(rel "$keep")/ is. So this chat can read the track but can't update STATE.md, and isn't asked to. Say so in your first reply, so the user knows this chat's work won't reach the track."
fi

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
if [ -z "$worktree" ]; then
  issues=$(bash "$here/../scripts/audit.sh" "$root" "$binding" start 2>/dev/null)
  if [ -n "$issues" ]; then
    add ""
    add "keep's check of this track:"
    add "$issues"
    add "Fix the ones that only move or de-duplicate text, or fill in what's missing, in your first save. Mention the ones that need the user once in this chat, at a natural pause, never before answering what they asked."
  fi
  if [ "$(bash "$here/../scripts/audit.sh" "$root" "$binding" due 2>/dev/null)" = due ]; then
    add ""
    add "keep's periodic review of this track is due. Start the keep audit skill for $binding now, without waiting for the user; it runs in the background on a cheaper model and reads only. When its list comes back, apply the items it marks lossless, write the other items to the track's review-<date>.md (or \"Nothing needs the user.\"; writing the file marks the review as handled) with an Inbox line pointing to it when it has items, commit the keep folder if it's its own git repo, and show the user the other items once, at a natural pause."
  fi
fi
emit "FEATURE.md" "$fdir/FEATURE.md" 2000
emit "CONTEXT.md" "$tdir/CONTEXT.md" 2600
emit "STATE.md" "$tdir/STATE.md" $(( budget - $(bytes "$out") - 200 )) "Inbox" "Current" "Next step"

if [ "$(bytes "$out")" -gt 9800 ]; then
  out="$(printf '%s' "$out" | lines_within 9600)"$'\n'"[Cut to stay under the hook output limit: read $(rel "$tdir")/STATE.md in full.]"
fi
printf '%s' "$out"
exit 0
