---
name: start
description: Bind this chat to a track of a feature and load its state. The user runs it at the start of a chat as /keep:start <feature>/<track>.
disable-model-invocation: true
---
Track: $ARGUMENTS

The keep folder is `${CLAUDE_PROJECT_DIR}/.keep/`. Each feature is a folder in it, and each track is a folder in its feature. If only a feature was given and it has exactly one track, that's the track.

**If no track was given, or it doesn't exist:**
1. List the tracks and their current work: `bash "${CLAUDE_SKILL_DIR}/../../scripts/status.sh" "${CLAUDE_PROJECT_DIR}"`.
2. Ask which track to use. If the user wants a new one:
   - Propose its name first and wait for the user to confirm or change it; create nothing before that. Use short, lowercase, hyphenated words named after the product or topic, so the name is easy to guess (for example `checkout/discounts`), not ticket keys. Names start with a letter or digit and use only letters, digits, `.`, `_` and `-`.
   - A new feature: copy `FEATURE.md` from `${CLAUDE_SKILL_DIR}/../../templates/` to `${CLAUDE_PROJECT_DIR}/.keep/<feature>/`, plus `DECISIONS.md` if the feature records its decisions there. Fill in the goal, source docs, where decisions go, and repos with the user; never guess them.
   - A new track: copy `CONTEXT.md`, `STATE.md` and `NOTES.md` from the same templates to `${CLAUDE_PROJECT_DIR}/.keep/<feature>/<track>/`, and fill in the names and the track's goal.
3. Refresh the index: `bash "${CLAUDE_SKILL_DIR}/../../scripts/index.sh" "${CLAUDE_PROJECT_DIR}"`. Then tell the user, in one line, the exact command to start it, `/keep:start <feature>/<track>`, and that it's listed in `.keep/INDEX.md`. Stop there.

**Otherwise:**
1. Read `${CLAUDE_PROJECT_DIR}/.keep/<feature>/FEATURE.md`, then the track's `CONTEXT.md` and `STATE.md` (Inbox first), then every file the first two list under "Read on start". If one doesn't exist yet, say so and continue.
2. Check what changed since the state was written: `bash "${CLAUDE_SKILL_DIR}/../../scripts/freshness.sh" "${CLAUDE_PROJECT_DIR}" "<feature>/<track>" "$PWD"`. Treat what STATE.md says about those repos as unconfirmed until you've checked it.
3. For the rest of this chat, work only within this track. Keep its STATE.md current; a hook enforces it after edits and research.
4. Reply with three lines: where things stand, what's in the Inbox and what changed in the repos, and the suggested next step. Then wait.
