---
name: save
description: Save this chat's state to its keep track (the user may call a track a workspace) so a new chat can continue with no briefing. Use it in a chat bound to a keep track before /clear, after repeated compactions, after a long discussion, or before stopping; in a chat that isn't bound, only when the user asks to save to keep.
allowed-tools: Bash(git -C "${CLAUDE_PROJECT_DIR}/.keep" add *) Bash(git -C "${CLAUDE_PROJECT_DIR}/.keep" commit *)
---
If `${CLAUDE_PROJECT_DIR}` has no `.keep/` folder, which happens when a chat moves to another folder after it starts, use the nearest folder at or above the current one that has a `.keep/` wherever this says `${CLAUDE_PROJECT_DIR}`.

Run each command below exactly as written, one per call, apart from that folder when it applies: keep pre-approves them in that form, so they run without permission prompts.

Update the bound track's STATE.md in `${CLAUDE_PROJECT_DIR}/.keep/<feature>/<track>/`. `cat "${CLAUDE_PROJECT_DIR}/.keep/.state/track-${CLAUDE_SESSION_ID}" 2>/dev/null` prints the track this chat is bound to, as `<feature>/<track>`. If it prints nothing, run the start skill first, then save to the track it binds: with the full name of the one track that clearly fits this chat's work, or with no name, so the user picks or creates one, when more than one could fit or none does. Write it for an agent with no memory of this chat. It's done when deleting this chat would lose nothing.

1. **Current:** the work in flight: branch or worktree, files touched, what works, what's left. Mark each line `[verified]` (checked against code, git or a test in this chat) or `[assumed]`. Include conclusions reached in discussion.
2. **Next step:** one concrete action that names the file and function to touch, or the command to run.
3. **Tickets:** check off only what passed its acceptance check. **Done log:** one line each, newest first: date · ticket · commit hash · how it was verified, or "unverified".
4. **Dead ends:** approaches tried or rejected and why, and areas not to touch. **Gotchas:** anything learned the hard way.
5. **Decisions:** check that every decision made in this chat is recorded where FEATURE.md says decisions go, with the options rejected and why; record any that aren't. A decision that affects another track also gets a line in that track's Inbox: date · from · what changed · affects.
6. Edit STATE.md in place: never rewrite it whole, and never delete a ticket or Done-log line. Leave an empty section with just its comment. Keep the file under 5,000 bytes by moving older Done-log lines and settled gotchas to NOTES.md.
7. If keep's check listed issues for this track in this chat, fix now the ones that only move or de-duplicate text or fill in what's missing, and list the others for the user in your reply. If it listed none, skip this.
8. If the user corrected the same mistake more than once, propose a one-line rule for FEATURE.md or CONTEXT.md. Show it; don't add it silently.
9. Don't commit unfinished code without asking. If the keep folder is its own git repo, commit it: `git -C "${CLAUDE_PROJECT_DIR}/.keep" add -A && git -C "${CLAUDE_PROJECT_DIR}/.keep" commit -m "<feature>/<track>: save"`.
10. Reply with "Saved.", then one line for each decision, Inbox line or rule you wrote, then "Type /clear, or start a new chat with /keep:start <feature>/<track>." with the track's full name.
