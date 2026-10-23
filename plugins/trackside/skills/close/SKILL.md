---
name: close
description: Close a finished track (the user may call a track a workspace) or feature: hand off what's still open, move it to the archive and update the index. Run it when the user types /trackside:close <feature>/<track> (or <feature> for a whole feature) or asks in words to close one; never on your own.
allowed-tools: Bash(bash "${CLAUDE_SKILL_DIR}/../../scripts/status.sh" *) Bash(bash "${CLAUDE_SKILL_DIR}/../../scripts/archive.sh" *) Bash(git -C "${CLAUDE_PROJECT_DIR}/.trackside" add *) Bash(git -C "${CLAUDE_PROJECT_DIR}/.trackside" commit *)
---
If `${CLAUDE_PROJECT_DIR}` has no `.trackside/` folder, which happens when a chat moves to another folder after it starts, use the nearest folder at or above the current one that has a `.trackside/` wherever this says `${CLAUDE_PROJECT_DIR}`.

Run each command below exactly as written, one per call, apart from that folder when it applies: trackside pre-approves them in that form, so they run without permission prompts.

Target: $ARGUMENTS

The trackside folder is `${CLAUDE_PROJECT_DIR}/.trackside/`.

1. If no target was given or it doesn't exist, list the tracks (`bash "${CLAUDE_SKILL_DIR}/../../scripts/status.sh" "${CLAUDE_PROJECT_DIR}"`) and ask which one. A target without a track means the whole feature.
2. Read the STATE.md of each track being closed and list what's still open: unchecked tickets, Inbox items, work under Current, and open questions. Also say how many chats are bound to it: `grep -lx "<feature>/<track>" "${CLAUDE_PROJECT_DIR}"/.trackside/.state/track-* 2>/dev/null | wc -l` (for a whole feature, `grep -l "^<feature>/"`).
3. Propose, in one list, where each open item goes: a line in another track's Inbox (say which), a decision to record where FEATURE.md says decisions go, or nowhere. If the track has Gotchas or lessons that are about a repo's own code or tooling and would help any chat in that repo, add each to the list with the file it would move to: that repo's `CLAUDE.md`, or the file the project's `CLAUDE.md` says holds that repo's commands and gotchas; when there are none, don't mention them. Ask once whether to close it with that list, and change nothing until the user confirms or corrects it.
4. Once the user confirms, write those Inbox lines and decisions, and move those lessons into their files; a repo's `CLAUDE.md` changes are left for the user to commit with that repo's work. If the trackside folder is its own git repo, commit it: `git -C "${CLAUDE_PROJECT_DIR}/.trackside" add -A`, then `git -C "${CLAUDE_PROJECT_DIR}/.trackside" commit -m "Before closing <target>"`.
5. Archive it: `bash "${CLAUDE_SKILL_DIR}/../../scripts/archive.sh" "${CLAUDE_PROJECT_DIR}" "<target>"`. This moves the folder into `.trackside/_archive/`, removes the chat bindings and git stamps that point at it, and refreshes the index. The track's own files are never deleted.
6. If the trackside folder is its own git repo, commit again with the message "Close <target>".
7. Reply with what moved and where, how many chats were unbound, and how to restore it: move the folder back out of `_archive/`.
