---
name: list
description: Show every keep feature and track with its current work, its last update and the command to start it. Use when the user asks which tracks exist or what's in progress.
allowed-tools: Bash(bash "${CLAUDE_SKILL_DIR}/../../scripts/index.sh" *)
---
1. Refresh the index: `bash "${CLAUDE_SKILL_DIR}/../../scripts/index.sh" "${CLAUDE_PROJECT_DIR}"`.
2. Show the contents of `${CLAUDE_PROJECT_DIR}/.keep/INDEX.md` as they are.
3. If a track is marked idle, add one line suggesting `/keep:close` for it. Don't close anything.
