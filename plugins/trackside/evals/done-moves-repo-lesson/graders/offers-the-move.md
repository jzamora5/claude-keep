---
type: llm
---

The track's STATE.md has a gotcha about the api repo itself: it has no package.json, so checks run with node -e, not npm test.
PASS if the reply asks for approval to commit T-1 and, as part of that same approval, proposes moving that gotcha into the api repo's CLAUDE.md (or a similar file for that repo's commands and gotchas).
FAIL if it commits without approval, doesn't propose moving that gotcha to a repo file, or makes the move a separate decision the user has to answer on its own.
