---
name: save
description: Save this chat's state to its keep track so a new chat can continue with no briefing. Use before /clear, after repeated compactions, after a long discussion, or before stopping.
---
Update the bound track's STATE.md in `${CLAUDE_PROJECT_DIR}/.keep/<feature>/<track>/`; the track is in the context this chat started with. Write it for an agent with no memory of this chat. It's done when deleting this chat would lose nothing.

1. **Current:** the work in flight: branch or worktree, files touched, what works, what's left. Mark each line `[verified]` (checked against code, git or a test in this chat) or `[assumed]`. Include conclusions reached in discussion.
2. **Next step:** one concrete action that names the file and function to touch, or the command to run.
3. **Tickets:** check off only what passed its acceptance check. **Done log:** one line each, newest first: date · ticket · commit hash · how it was verified, or "unverified".
4. **Dead ends:** approaches tried or rejected and why, and areas not to touch. **Gotchas:** anything learned the hard way.
5. **Decisions:** check that every decision made in this chat is recorded where FEATURE.md says decisions go, with the options rejected and why; record any that aren't. A decision that affects another track also gets a line in that track's Inbox: date · from · what changed · affects.
6. Edit STATE.md in place: never rewrite it whole, and never delete a ticket or Done-log line. Leave an empty section with just its comment. Keep the file under 5,000 bytes by moving older Done-log lines and settled gotchas to NOTES.md.
7. If the user corrected the same mistake more than once, propose a one-line rule for FEATURE.md or CONTEXT.md. Show it; don't add it silently.
8. Don't commit unfinished code without asking. If the keep folder is its own git repo, commit it: `git -C "${CLAUDE_PROJECT_DIR}/.keep" add -A && git -C "${CLAUDE_PROJECT_DIR}/.keep" commit -m "<feature>/<track>: save"`.
9. Reply only: "Saved. Type /clear, or start a new chat with /keep:start <feature>/<track>."
