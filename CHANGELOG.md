# Changelog

## 0.5.1 · 2026-10-21

- A chat that moves to another folder after it starts keeps `CLAUDE_PROJECT_DIR` from the folder it started in. When that folder has no `.keep/`, the hooks, scripts and skills now use the nearest `.keep/` at or above the folder the chat works in, instead of finding nothing and staying silent.
- An eval suite in `plugins/keep/evals/` checks eight behaviors in real headless sessions with `claude plugin eval`; `bash tests/evals.sh` runs it.

## 0.5.0 · 2026-10-21

- Say yes to a track the agent suggests, and it binds the chat and carries on with your request: there's no command to type. A ticket still waits for your approval of its plan, as with `/keep:next`. The agent can now run the start skill, but only after you agree. The chat is named after the track at your next message.
- `/keep:start <name> <request>` binds and starts on the request in one message.
- A new track is proposed in one message, with its goal and, for a new feature, the repos, decisions file and planning filled in from what the agent finds. Once you confirm, it's created and the chat is bound to it, with no second `/keep:start`.
- The Stop hook asks at most once every 15 minutes (`KEEP_SAVE_MINUTES`; 0 restores asking after every working turn), and only for Current and Next step.
- Edits to files outside the project folder, such as scratch files, no longer count as work.
- Worktree sessions that can't save to `.keep/` are no longer asked to after every turn; the agent says the chat can read the track but not save it.
- When a feature names source docs but has no digest, the agent suggests `/keep:digest`. Ending a ticket says "Type /clear, then say next".
- The agent offers a track only when your message starts work on it, not for a quick question.
- Ask the agent to close a track and it runs `/keep:close`, which still asks about every open item before changing anything.
- Freshness and the git stamps leave `.keep/` out, so in a project whose repo holds `.keep/`, the state's own files no longer show up as code changes. The first check after upgrading may still report a difference once.
- `/keep:next`, `/keep:done` and `/keep:save` act only in a chat bound to a track, so they don't start in an unrelated chat. In a chat that isn't bound, next and done say so, and save asks which track to bind first.
- Closing proposes where each open item goes in one list, and asks once.
- Switching a chat to another track while it has unsaved work saves that work to its own track first, instead of leaving it for the new one. `/keep:start off` unbinds a chat.
- `/keep:done` stops when a check fails, and marks the ticket done in STATE.md only after you approve the commit.
- The skills run keep's own scripts and `.keep/` commits without permission prompts (`allowed-tools`). The README shows a rule that allows the STATE.md edits the reminder asks for.
- When a message starts work that matches no track, the agent offers once to create one. The README says what to do first.
- `/keep:next` checks only the repos the ticket touches, and a new feature lists only the repos the work involves.
- The 15-minute clock is each chat's own last save, so another chat editing the same STATE.md doesn't silence the reminder. The reminder and the start of each chat also ask for decisions to be recorded when they're made, and `/keep:save` lists what it recorded.
- The track list and the index show a track's goal when nothing is in flight.
- NOTES.md is no longer read at every start; new tracks read it when needed.
- The git offer comes once, when `.keep/` is created, as two separate choices (`setup-git.sh ignore history`).
- Without jq, binding says that keep's hooks are off.
- New tracks drop template lines that can't be filled in, and the save and compaction messages give the track's short start command.

## 0.4.0 · 2026-10-21

- `/keep:start` takes a single name when only one track matches it: a feature with one track, or a track name used by only one feature. The index and the listings show the shortest command for each track.
- In a chat that isn't bound yet, the agent's first reply names the track that matches what you asked about, with its start command. It only suggests; nothing is bound until you run the command.
- Binding a chat that already has work in it offers `/keep:save`, so what the chat knew before reaches the track.

## 0.3.1 · 2026-10-20

- Edits to Claude's own files under `~/.claude/` (memory, plans, settings) no longer mark the chat dirty.
- Only keep's own `doc-expert` subagent is exempt from the gate; another plugin's agent with a similar name counts as research.
- Saving the state no longer hashes the contents of untracked files, so a large untracked file can't slow the hooks. Freshness still reports an untracked file that changed after the last save.
- The index writes its temporary file inside `.keep/.state/`, so a run that's killed midway can't leave a file for git to pick up.

## 0.3.0 · 2026-10-20

**Breaking:** `KEEP_FOLDER` is removed. The keep folder is always `.keep/` in the project root; a setup that used another folder falls back to `.keep/` without a warning. To keep your tracks, rename that folder to `.keep`.

- Edits inside Claude Code worktrees (`.claude/worktrees/`) mark the chat dirty.
- Skills run their commands from the project root instead of the working directory.
- Freshness reports a reset to an older commit and changes to files that were already uncommitted.
- Chats side by side no longer collide on temporary files.
- `/keep:start <feature>` with a single track uses that track in the skill too, as the bind hook does.
- The Stop hook answers with Stop hook feedback instead of an error.
- Git stamps move to `.keep/.state/` and are removed when a track is closed.
- In a worktree session, the project's own repo is stamped and checked in the worktree.
- The README describes what the gate covers, including its limits.

## 0.2.0 · 2026-10-20

- `.keep/INDEX.md`, generated at every chat start and state save.
- `/keep:list` and `/keep:close`, which archives a track or feature into `.keep/_archive/`.
- `/keep:start` asks you to approve a name before creating a feature or track.
- Idle tracks are flagged after 14 days, and old session files are cleared after 30.

## 0.1.0 · 2026-10-20

- First version: features and tracks, the Stop-hook gate, reload after a compaction, git stamps, and `/keep:start`, `/keep:next`, `/keep:done`, `/keep:save` and `/keep:digest`.
