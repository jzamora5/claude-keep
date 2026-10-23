#!/usr/bin/env bash
set -euo pipefail
bash "$(dirname "$0")/../_fixture/sandbox.sh"
# Save the track once through keep's edit hook, so it records the design doc, then change the doc's rules.
H="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p .keep/.state
printf 'demo/tickets\n' > .keep/.state/track-scaffold
printf '{"session_id":"scaffold","tool_name":"Edit","tool_input":{"file_path":"%s/.keep/demo/tickets/STATE.md"}}' "$PWD" \
  | CLAUDE_PROJECT_DIR="$PWD" "$H/hooks/track.sh" >/dev/null
rm -f .keep/.state/track-scaffold .keep/.state/saved-scaffold
awk '{ sub(/A code never makes the total negative\./, "A code may make the total negative; the difference is refunded as store credit."); print }' docs/spec.md > docs/spec.tmp
mv docs/spec.tmp docs/spec.md
