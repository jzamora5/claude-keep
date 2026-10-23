#!/usr/bin/env bash
set -euo pipefail
bash "$(dirname "$0")/../_fixture/sandbox.sh"
# T-1 is implemented but not committed, and the state holds a gotcha about the api repo itself.
cat > api/app.js <<'EOJ'
function applyDiscount(total, code) {
  if (code === "TEN") return total * 0.9;
  return total;
}
module.exports = { applyDiscount };
EOJ
awk '{ sub(/^- Ticket: none \[verified\]$/, "- T-1 [verified]: applyDiscount takes 10% off for TEN in api/app.js; not committed yet"); print }
     /^## Gotchas/ { print "- api: there is no package.json, so run checks with node -e, not npm test." }' .trackside/demo/tickets/STATE.md > .trackside/demo/tickets/STATE.tmp
mv .trackside/demo/tickets/STATE.tmp .trackside/demo/tickets/STATE.md
git -C .trackside commit -qam "T-1 in progress"
