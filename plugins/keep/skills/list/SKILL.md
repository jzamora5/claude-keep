---
name: list
description: Show every keep feature and track with its current work, its last update and the command to start it. Use when the user asks which tracks exist or what's in progress.
---
1. Refresh the index: `bash "${CLAUDE_SKILL_DIR}/../../scripts/index.sh" "$PWD"`.
2. Show the contents of `INDEX.md` in the keep folder (`.keep/`, or the folder `KEEP_FOLDER` names) as they are.
3. If a track is marked idle, add one line suggesting `/keep:close` for it. Don't close anything.
