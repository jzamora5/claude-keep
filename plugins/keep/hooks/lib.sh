# Shared setup for the keep hooks. Sourced, not run.
# Every hook fails open: without jq, a keep folder or a session id, it exits 0 and changes nothing,
# so keep never breaks a session.
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0
. "$(dirname "${BASH_SOURCE[0]}")/../scripts/common.sh"

input=$(cat)
root="${CLAUDE_PROJECT_DIR:-$PWD}"
keep=$(keep_dir "$root")
[ -d "$keep" ] || exit 0
st="$keep/.state"
if [ ! -d "$st" ]; then
  mkdir -p "$st" || exit 0
  printf '*\n' > "$st/.gitignore"
fi

field() { jq -r "$1 // \"\"" <<<"$input" 2>/dev/null; }
rel() { printf '%s' "${1#"$root"/}"; }

sid=$(field .session_id)
[[ "$sid" =~ ^[A-Za-z0-9._-]+$ ]] || exit 0
binding=$(cat "$st/track-$sid" 2>/dev/null || true)
