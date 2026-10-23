#!/usr/bin/env bash
set -euo pipefail
bash "$(dirname "$0")/../_fixture/sandbox.sh"
# A review track whose items start clean, with one review in flight and a detail that belongs to that review only.
H="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p .trackside/demo/reviews
printf '# Track: demo/reviews\n\n**Goal:** review pull requests on api and web, one per ticket.\n\n**Each item starts clean:** yes\n\n**Rules for this track:**\n- Post comments only after the user approves the review.\n' > .trackside/demo/reviews/CONTEXT.md
sed 's#<feature>/<track>#demo/reviews#' "$H/templates/LESSONS.md" > .trackside/demo/reviews/LESSONS.md
printf '# Notes: demo/reviews\n' > .trackside/demo/reviews/NOTES.md
cat > .trackside/demo/reviews/STATE.md <<'EOS'
# State: demo/reviews

## Inbox

## Current
- api#7 [verified]: reviewed at abc1234, 1 finding, not blocking. The user approved it as a Comment review.

## Next step
- Post the api#7 review once the user has approved it.

## Tickets
- [ ] api#7: discount code parsing — acceptance: review submitted with its type

## Done log

## Dead ends

## Gotchas
- api#7: the diff renames applyDiscount to applyCode, so grep for both names.

## Open questions / Blocked
EOS
git -C .trackside add -A
git -C .trackside commit -qm "Add demo/reviews"
