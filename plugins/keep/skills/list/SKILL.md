---
name: list
description: Show every keep feature and track (the user may call a track a workspace) with its current work, its last update and the command to start it. Use when the user asks which tracks or workspaces exist or what's in progress.
allowed-tools: Bash(bash "${CLAUDE_SKILL_DIR}/../../scripts/index.sh" *)
---
If `${CLAUDE_PROJECT_DIR}` has no `.keep/` folder, which happens when a chat moves to another folder after it starts, use the nearest folder at or above the current one that has a `.keep/` wherever this says `${CLAUDE_PROJECT_DIR}`.

Run each command below exactly as written, one per call, apart from that folder when it applies: keep pre-approves them in that form, so they run without permission prompts.

1. Refresh the index: `bash "${CLAUDE_SKILL_DIR}/../../scripts/index.sh" "${CLAUDE_PROJECT_DIR}"`.
2. Show the contents of `${CLAUDE_PROJECT_DIR}/.keep/INDEX.md` as they are.
3. If a track is marked idle, add one line suggesting `/keep:close` for it. Don't close anything.
