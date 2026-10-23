#!/usr/bin/env bash
# rename.sh <project root> <feature>[/<track>] <new name>: rename a track within its feature, or a whole
# feature. Chats bound to it stay bound and get the new name at their next message, its git stamps follow it,
# and the index is refreshed. Other mentions of the old name are listed, not changed.
set -uo pipefail
. "$(dirname "$0")/common.sh"
root=$(keep_root "${1:?project root}" "$PWD")
target="${2:?<feature> or <feature>/<track>}"
new="${3:?new name}"
keep=$(keep_dir "$root")
st="$keep/.state"

feature="${target%%/*}"
track=""
[[ "$target" == */* ]] && track="${target#*/}"
valid_name "$feature" || { echo "Not a feature name: $feature" >&2; exit 1; }
if [ -n "$track" ] && ! valid_name "$track"; then echo "Not a track name: $track" >&2; exit 1; fi
valid_name "$new" || { echo "Not a valid name: $new. Use letters, digits, '.', '_' and '-', starting with a letter or digit." >&2; exit 1; }
if [ -n "$track" ]; then
  [ "$new" != off ] || { echo "A track can't be named off: /keep:start off unbinds a chat." >&2; exit 1; }
  old="$feature/$track"
  to="$feature/$new"
  [ -f "$keep/$old/STATE.md" ] || { echo "No track $old." >&2; exit 1; }
else
  old="$feature"
  to="$new"
  [ -d "$keep/$old" ] || { echo "No feature $old." >&2; exit 1; }
fi
[ ! -e "$keep/$to" ] || { echo "$(rel "$keep/$to") already exists." >&2; exit 1; }

mv "$keep/$old" "$keep/$to" || exit 1
echo "Renamed $(rel "$keep/$old") to $(rel "$keep/$to")"

# The headers keep's templates write ("# State: <feature>/<track>" and the like) name the track or feature.
old_re="${old//./\\.}"
for f in "$keep/$to"/*.md "$keep/$to"/*/*.md; do
  [ -f "$f" ] || continue
  sed -E "s,^(# (State|Track|Notes|Feature|Decisions): )$old_re([^A-Za-z0-9._-]|$),\\1$to\\3," "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done

kept=0
renamed=0
for b in "$st"/track-*; do
  [ -f "$b" ] || continue
  v=$(cat "$b")
  nv=""
  if [ -n "$track" ]; then
    [ "$v" = "$old" ] && nv="$to"
  else
    [[ "$v" == "$old"/* ]] && nv="$to/${v#*/}"
  fi
  [ -n "$nv" ] || continue
  sid="${b##*/track-}"
  printf '%s\n' "$nv" > "$b"
  kept=$((kept + 1))
  # A chat the user named keeps its name. Only a hook can name a chat, so the bind hook applies this at the
  # chat's next message.
  [ -n "$(chat_name "$keep" "$sid")" ] && continue
  printf '%s' "$nv" > "$st/title-$sid"
  renamed=$((renamed + 1))
done
echo "Chats kept bound: $kept, renamed at their next message: $renamed"
for m in "$st"/named-*; do
  [ -f "$m" ] || continue
  v=$(cat "$m")
  if [ -n "$track" ]; then
    [ "$v" = "$old" ] && printf '%s\n' "$to" > "$m"
  else
    [[ "$v" == "$old"/* ]] && printf '%s\n' "$to/${v#*/}" > "$m"
  fi
done

# The deep-review record moves too, so a renamed track isn't reviewed again just for its new name.
if [ -n "$track" ]; then
  s=$(stamp_file "$keep" "$old")
  [ -f "$s" ] && mv "$s" "$(stamp_file "$keep" "$to")"
  [ -f "$st/deep-$feature@$track" ] && mv "$st/deep-$feature@$track" "$st/deep-$feature@$new"
else
  for s in "$st/stamp-$old@"* "$st/deep-$old@"*; do
    [ -f "$s" ] || continue
    case "$s" in */stamp-*) mv "$s" "$st/stamp-$new@${s#*@}" ;; *) mv "$s" "$st/deep-$new@${s#*@}" ;; esac
  done
fi

bash "$(dirname "$0")/index.sh" "$root"

# A feature's name is often a plain word, so only its "<feature>/" paths are looked for.
needle="$old"
[ -z "$track" ] && needle="$old/"
mentions=$(grep -rlF -- "$needle" "$keep" --exclude-dir=.git --exclude-dir=.state --exclude=INDEX.md 2>/dev/null | sed "s#^$root/##" | sort)
[ -n "$mentions" ] && printf 'Still mention %s:\n%s\n' "$needle" "$mentions"
exit 0
