---
name: next
description: Propose the next ticket from the bound track's STATE.md with a short plan, and wait for approval before writing any code.
---
1. Read the bound track's STATE.md in `${CLAUDE_PROJECT_DIR}/.keep/<feature>/<track>/`. Handle the Inbox first: for each item, say which ticket it affects and propose how to fold it in (a new ticket, a change to one, a gotcha or an open question).
2. If Current has work in progress, propose continuing it. Otherwise take the first unchecked ticket.
3. If the ticket touches code, check where the code stands first: `git status` and `git log --oneline -10` in each repo FEATURE.md lists, then that repo's baseline tests. Report uncommitted work, a branch that's behind, or failing tests before anything else.
4. Read only what the ticket needs. Ask the `doc-expert` subagent about the feature's source docs, passing it their paths and where decisions are recorded, both from FEATURE.md.
5. If FEATURE.md says the feature plans with OpenSpec, draft the plan with its propose step. Otherwise, reply with: the ticket, a plan of at most about 8 steps, the files you expect to touch, the acceptance check you'll run, any open question that blocks it, and any recorded decision or rejected option the plan would go against.
6. Write no code until the user approves. If something is unknown, propose a spike or ask; never guess.
