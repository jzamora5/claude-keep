---
name: close
description: Close a finished track or feature: hand off what's still open, move it to the archive and update the index. Run it when the user types /keep:close <feature>/<track> (or <feature> for a whole feature) or asks in words to close one; never on your own.
allowed-tools: Bash(bash "${CLAUDE_SKILL_DIR}/../../scripts/status.sh" *) Bash(bash "${CLAUDE_SKILL_DIR}/../../scripts/archive.sh" *) Bash(git -C "${CLAUDE_PROJECT_DIR}/.keep" add *) Bash(git -C "${CLAUDE_PROJECT_DIR}/.keep" commit *)
---
Target: $ARGUMENTS

The keep folder is `${CLAUDE_PROJECT_DIR}/.keep/`.

1. If no target was given or it doesn't exist, list the tracks (`bash "${CLAUDE_SKILL_DIR}/../../scripts/status.sh" "${CLAUDE_PROJECT_DIR}"`) and ask which one. A target without a track means the whole feature.
2. Read the STATE.md of each track being closed and list what's still open: unchecked tickets, Inbox items, work under Current, and open questions. Also say how many chats are bound to it: `grep -lx "<feature>/<track>" "${CLAUDE_PROJECT_DIR}"/.keep/.state/track-* 2>/dev/null | wc -l` (for a whole feature, `grep -l "^<feature>/"`).
3. Propose, in one list, where each open item goes: a line in another track's Inbox (say which), a decision to record where FEATURE.md says decisions go, or nowhere. Ask once, and change nothing until the user confirms or corrects the list.
4. Once the user confirms, write those Inbox lines and decisions. If the keep folder is its own git repo, commit it: `git -C "${CLAUDE_PROJECT_DIR}/.keep" add -A && git -C "${CLAUDE_PROJECT_DIR}/.keep" commit -m "Before closing <target>"`.
5. Archive it: `bash "${CLAUDE_SKILL_DIR}/../../scripts/archive.sh" "${CLAUDE_PROJECT_DIR}" "<target>"`. This moves the folder into `.keep/_archive/`, removes the chat bindings and git stamps that point at it, and refreshes the index. The track's own files are never deleted.
6. If the keep folder is its own git repo, commit again with the message "Close <target>".
7. Reply with what moved and where, how many chats were unbound, and how to restore it: move the folder back out of `_archive/`.
