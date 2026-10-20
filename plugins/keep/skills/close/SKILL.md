---
name: close
description: Close a finished track or feature: hand off what's still open, move it to the archive and update the index. The user runs it as /keep:close <feature>/<track>, or /keep:close <feature> for a whole feature.
disable-model-invocation: true
---
Target: $ARGUMENTS

The keep folder is `.keep/` in the project root, or the folder `KEEP_FOLDER` names.

1. If no target was given or it doesn't exist, list the tracks (`bash "${CLAUDE_SKILL_DIR}/../../scripts/status.sh"`) and ask which one. A target without a track means the whole feature.
2. Read the STATE.md of each track being closed and list what's still open: unchecked tickets, Inbox items, work under Current, and open questions. Also say how many chats are bound to it: `grep -lx "<feature>/<track>" .keep/.state/track-* 2>/dev/null | wc -l` (for a whole feature, `grep -l "^<feature>/"`).
3. For each open item, ask where it goes: a line in another track's Inbox (say which), a decision to record where FEATURE.md says decisions go, or nowhere. Change nothing until the user answers.
4. Once the user approves, write those Inbox lines and decisions. If the keep folder is its own git repo, commit it: `git -C .keep add -A && git -C .keep commit -m "Before closing <target>"`.
5. Archive it: `bash "${CLAUDE_SKILL_DIR}/../../scripts/archive.sh" "$PWD" "<target>"`. This moves the folder into `.keep/_archive/`, removes the chat bindings that point at it, and refreshes the index. Nothing is deleted.
6. If the keep folder is its own git repo, commit again: `git -C .keep add -A && git -C .keep commit -m "Close <target>"`.
7. Reply with what moved and where, how many chats were unbound, and how to restore it: move the folder back out of `_archive/`.
