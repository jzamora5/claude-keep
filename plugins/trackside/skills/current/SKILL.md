---
name: current
description: Show which track this chat is on (the user may call a track a workspace), with its current work, next step and start command. Run it when the user types /trackside:current or asks which track or workspace this chat is on.
allowed-tools: Bash(bash "${CLAUDE_SKILL_DIR}/../../scripts/current.sh" *)
---
If `${CLAUDE_PROJECT_DIR}` has no `.trackside/` folder, which happens when a chat moves to another folder after it starts, use the nearest folder at or above the current one that has a `.trackside/` wherever this says `${CLAUDE_PROJECT_DIR}`.

Run each command below exactly as written, one per call, apart from that folder when it applies: trackside pre-approves them in that form, so they run without permission prompts.

Run `bash "${CLAUDE_SKILL_DIR}/../../scripts/current.sh" "${CLAUDE_PROJECT_DIR}" "${CLAUDE_SESSION_ID}"` and show what it prints as it is. If the chat isn't bound, add one line: say what you're working on, or run one of the listed start commands.
