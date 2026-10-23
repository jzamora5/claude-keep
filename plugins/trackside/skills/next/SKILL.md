---
name: next
description: In a chat bound to a track (the user may call a track a workspace), propose the next ticket from the track's STATE.md with a short plan, and wait for approval before writing any code.
---
If `${CLAUDE_PROJECT_DIR}` has no `.trackside/` folder, which happens when a chat moves to another folder after it starts, use the nearest folder at or above the current one that has a `.trackside/` wherever this says `${CLAUDE_PROJECT_DIR}`.

`cat "${CLAUDE_PROJECT_DIR}/.trackside/.state/track-${CLAUDE_SESSION_ID}" 2>/dev/null` prints the track this chat is bound to, as `<feature>/<track>`. If it prints nothing, say that no track is bound and offer to bind one with the start skill; continue only once it's bound.

1. Read the bound track's STATE.md in `${CLAUDE_PROJECT_DIR}/.trackside/<feature>/<track>/`. Handle the Inbox first: for each item, say which ticket it affects and propose how to fold it in (a new ticket, a change to one, a gotcha or an open question).
2. If Current has work in progress, propose continuing it. Otherwise take the first unchecked ticket.
3. If the ticket touches code, check where the code stands first, in each repo the ticket touches: `git status`, `git log --oneline -10`, then that repo's baseline tests. Report uncommitted work, a branch that's behind, or failing tests before anything else.
4. Read only what the ticket needs. Ask the `doc-expert` subagent about the feature's source docs, passing it their paths and where decisions are recorded, both from FEATURE.md.
5. If FEATURE.md says the feature plans with OpenSpec, draft the plan with its propose step. Otherwise, reply with: the ticket, a plan of at most about 8 steps, the files you expect to touch, the acceptance check you'll run, any open question that blocks it, and any recorded decision or rejected option the plan would go against.
6. Write no code until the user approves. If something is unknown, propose a spike or ask; never guess.
