---
name: rename
description: Rename a keep track (the user may call a track a workspace) or a whole feature, keeping its chats bound. Run it when the user types /keep:rename <feature>/<track> <new name> (or <feature> <new name>) or asks in words to rename one; never on your own.
allowed-tools: Bash(bash "${CLAUDE_SKILL_DIR}/../../scripts/rename.sh" *) Bash(git -C "${CLAUDE_PROJECT_DIR}/.keep" add *) Bash(git -C "${CLAUDE_PROJECT_DIR}/.keep" commit *)
---
If `${CLAUDE_PROJECT_DIR}` has no `.keep/` folder, which happens when a chat moves to another folder after it starts, use the nearest folder at or above the current one that has a `.keep/` wherever this says `${CLAUDE_PROJECT_DIR}`.

Run each command below exactly as written, one per call, apart from that folder when it applies: keep pre-approves them in that form, so they run without permission prompts.

Arguments: $ARGUMENTS

1. Work out what to rename and the new name. "This track" means the one this chat is bound to: `cat "${CLAUDE_PROJECT_DIR}/.keep/.state/track-${CLAUDE_SESSION_ID}" 2>/dev/null`. A track's new name stays in its feature. Ask only if either is unclear; ask nothing else.
2. Rename it: `bash "${CLAUDE_SKILL_DIR}/../../scripts/rename.sh" "${CLAUDE_PROJECT_DIR}" "<feature>[/<track>]" "<new name>"`. It moves the folder, updates every reference to it inside `.keep/`, keeps every chat bound to it (chats named after the track get the new name at their next message; chats the user named keep theirs), moves its git stamps and review record, and refreshes the index.
3. Update mentions of the old name outside `.keep/` yourself, without asking (for a track, its full name `<feature>/<track>` and its `.keep/` path; for a feature, its tracks' full names and its `.keep/<feature>/` path): the project's `CLAUDE.md` files and the user's saved memory notes for this project (the `memory/` folder under `~/.claude/projects/` whose name is the project folder's path with every `/` turned into `-`). Don't write anything about the rename in `STATE.md`.
4. If the keep folder is its own git repo, commit it: `git -C "${CLAUDE_PROJECT_DIR}/.keep" add -A && git -C "${CLAUDE_PROJECT_DIR}/.keep" commit -m "Rename <old> to <new>"`.
5. Reply in at most three lines: the old and new names, how many chats stayed bound, the new start command (`/keep:start <feature>/<track>`), and the files outside `.keep/` you updated.
