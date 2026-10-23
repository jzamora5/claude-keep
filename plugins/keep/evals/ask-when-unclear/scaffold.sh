#!/usr/bin/env bash
set -euo pipefail
bash "$(dirname "$0")/../_fixture/sandbox.sh"
# A second feature whose track overlaps demo/tickets' T-3, so the prompt fits two tracks.
mkdir -p .keep/checkout/web
printf '# Feature: checkout\n\n**Goal:** A new checkout page.\n\n**Repos:** web\n' > .keep/checkout/FEATURE.md
printf '# Track: checkout/web\n\n**Goal:** Build the new checkout page in web/, including how the order total is shown.\n' > .keep/checkout/web/CONTEXT.md
printf '# State: checkout/web\n\n## Inbox\n\n## Current\n- Ticket: none\n\n## Next step\n\n## Tickets\n- [ ] W-1: lay out the checkout page — acceptance: web/checkout.html renders\n\n## Done log\n' > .keep/checkout/web/STATE.md
printf '# Notes: checkout/web\n' > .keep/checkout/web/NOTES.md
git -C .keep add -A
git -C .keep commit -q -m "Add checkout/web"
