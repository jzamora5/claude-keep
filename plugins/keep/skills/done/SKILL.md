---
name: done
description: In a chat bound to a keep track, verify the current ticket, update the feature's docs and the track's STATE.md, summarize for review, and commit only after approval.
allowed-tools: Bash(git -C "${CLAUDE_PROJECT_DIR}/.keep" add *) Bash(git -C "${CLAUDE_PROJECT_DIR}/.keep" commit *)
---
`cat "${CLAUDE_PROJECT_DIR}/.keep/.state/track-${CLAUDE_SESSION_ID}" 2>/dev/null` prints the track this chat is bound to, as `<feature>/<track>`. If it prints nothing, say that no track is bound and stop.

1. Run the ticket's acceptance check plus the test and lint commands for each repo it touched. If any of them fails, report it and stop: the ticket isn't done.
2. Summarize for review: what changed per file, how it was verified (command and result), what was left out, and any deviation from the source docs.
3. Keep the feature's documents current: update the source docs, or the tickets they track, that this change makes outdated. If none is affected, add "Docs: no change, because …" to the Done-log line.
4. Check that every decision made during the ticket, deviations and resolved unknowns included, is recorded where FEATURE.md says decisions go, with the options rejected and why; record any that aren't. If one affects another track, add a line to that track's Inbox: date · from · what changed · affects.
5. Ask for approval to commit, and wait. If the user wants changes instead, make them and start again from step 1.
6. Only after approval, commit in each repo in its own style (check its `git log`). Then update the track's STATE.md in `${CLAUDE_PROJECT_DIR}/.keep/<feature>/<track>/`: check off the ticket, add a Done-log line (date · ticket · commit hashes · how verified), clear Current, and add Dead ends and Gotchas. Until then, the ticket stays open in STATE.md.
7. Pushing and opening a pull request need a separate go-ahead. If the feature plans with OpenSpec, archive the change once it's merged.
8. If the keep folder is its own git repo, commit it: `git -C "${CLAUDE_PROJECT_DIR}/.keep" add -A && git -C "${CLAUDE_PROJECT_DIR}/.keep" commit -m "<feature>/<track>: <ticket> done"`.
9. End with: "Type /clear, then say next."
