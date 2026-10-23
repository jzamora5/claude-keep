---
name: done
description: In a chat bound to a keep track (the user may call a track a workspace), verify the current ticket, update the feature's docs and the track's STATE.md, summarize for review, and commit only after approval.
allowed-tools: Bash(git -C "${CLAUDE_PROJECT_DIR}/.keep" add *) Bash(git -C "${CLAUDE_PROJECT_DIR}/.keep" commit *)
---
If `${CLAUDE_PROJECT_DIR}` has no `.keep/` folder, which happens when a chat moves to another folder after it starts, use the nearest folder at or above the current one that has a `.keep/` wherever this says `${CLAUDE_PROJECT_DIR}`.

Run each command below exactly as written, one per call, apart from that folder when it applies: keep pre-approves them in that form, so they run without permission prompts.

`cat "${CLAUDE_PROJECT_DIR}/.keep/.state/track-${CLAUDE_SESSION_ID}" 2>/dev/null` prints the track this chat is bound to, as `<feature>/<track>`. If it prints nothing, say that no track is bound and stop.

1. Run the ticket's acceptance check plus the test and lint commands for each repo it touched. If any of them fails, report it and stop: the ticket isn't done.
2. Summarize for review: what changed per file, how it was verified (command and result), what was left out, and any deviation from the source docs.
3. Keep the feature's documents current: update the source docs, or the tickets they track, that this change makes outdated. If none is affected, add "Docs: no change, because …" to the Done-log line.
4. Check that every decision made during the ticket, deviations and resolved unknowns included, is recorded where FEATURE.md says decisions go, with the options rejected and why; record any that aren't. If one affects another track, add a line to that track's Inbox: date · from · what changed · affects.
5. Ask for approval to commit, and wait. If the user wants changes instead, make them and start again from step 1.
6. Only after approval, commit in each repo in its own style (check its `git log`). Then update the track's STATE.md in `${CLAUDE_PROJECT_DIR}/.keep/<feature>/<track>/`: check off the ticket, add a Done-log line (date · ticket · commit hashes · how verified), clear Current, and add Dead ends and Gotchas. Until then, the ticket stays open in STATE.md.
7. Pushing and opening a pull request need a separate go-ahead. If the feature plans with OpenSpec, archive the change once it's merged.
8. If keep's check listed issues for this track in this chat, fix now the ones that only move or de-duplicate text or fill in what's missing, and list the others for the user in your reply. If it listed none, skip this.
9. If the keep folder is its own git repo, commit it: `git -C "${CLAUDE_PROJECT_DIR}/.keep" add -A && git -C "${CLAUDE_PROJECT_DIR}/.keep" commit -m "<feature>/<track>: <ticket> done"`.
10. End with: "Type /clear, then say next."
