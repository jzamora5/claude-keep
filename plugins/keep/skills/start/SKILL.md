---
name: start
description: Bind this chat to a keep track (the user may call a track a workspace) and load its state, create a new track, or unbind the chat. Run it when the user types /keep:start, asks to work on a track, or agrees to a track you suggested. Never bind a chat the user hasn't agreed to.
allowed-tools: Bash(bash "${CLAUDE_SKILL_DIR}/../../scripts/bind.sh" *) Bash(bash "${CLAUDE_SKILL_DIR}/../../scripts/status.sh" *) Bash(bash "${CLAUDE_SKILL_DIR}/../../scripts/freshness.sh" *) Bash(bash "${CLAUDE_SKILL_DIR}/../../scripts/setup-git.sh" *)
---
If `${CLAUDE_PROJECT_DIR}` has no `.keep/` folder, which happens when a chat moves to another folder after it starts, use the nearest folder at or above the current one that has a `.keep/` wherever this says `${CLAUDE_PROJECT_DIR}`.

Arguments: $ARGUMENTS

The keep folder is `${CLAUDE_PROJECT_DIR}/.keep/`. Each feature is a folder in it, and each track is a folder in its feature. The first word of the arguments names the track: `<feature>/<track>`, or a single name when it matches exactly one track (a feature that has only one track, or else a track name used by only one feature). Anything after it is the user's request.

To bind the chat: `bash "${CLAUDE_SKILL_DIR}/../../scripts/bind.sh" "${CLAUDE_PROJECT_DIR}" "${CLAUDE_SESSION_ID}" "<name>"`. It prints the track it bound, or why it couldn't, and a note when keep's hooks can't run; pass any note on to the user.
- If it says the chat has unsaved work on another track, run `/keep:save` for that track first, then bind again. If the user says that work doesn't belong to that track, unbind first instead.
- `off` as the name unbinds the chat. Tell the user if its work since the last save wasn't saved, and stop there.

**If no name was given, or it matches no track or several:**
1. List the tracks, their current work or goal, and the command that starts each: `bash "${CLAUDE_SKILL_DIR}/../../scripts/status.sh" "${CLAUDE_PROJECT_DIR}"`. If the name matched several, say which ones.
2. Ask which one to use. Once the user picks one, bind it and continue under "Once bound".
3. If none fits, propose a new track in one message, and create nothing until the user confirms or corrects it:
   - Its name, `<feature>/<track>`, in an existing feature when one fits. Use short, lowercase, hyphenated words named after the product or topic, so the name is easy to guess (for example `checkout/discounts`), not ticket keys. Names start with a letter or digit and use only letters, digits, `.`, `_` and `-`. A track can't be named `off`.
   - Its goal, from what the user said.
   - For a new feature, its FEATURE.md values, filled in from what you can find instead of asked one by one: repos (the ones this work involves, picked from the git folders that `find "${CLAUDE_PROJECT_DIR}" -maxdepth 2 -name .git -not -path "*/.claude/*"` finds, relative to the project root, `.` for the root itself; ask when it isn't clear), source docs (only the ones the user named, otherwise "none yet"), decisions (`DECISIONS.md` in the feature folder, unless the user named a source doc section for them), and planning (`openspec` if `${CLAUDE_PROJECT_DIR}/openspec/` exists, otherwise none). Never guess a goal or a source doc.
   - If `${CLAUDE_PROJECT_DIR}/.keep/` doesn't exist yet, also offer two separate choices: keeping `.keep/` out of the project's git, when the project is a git repo, so the state isn't committed with the code; and giving `.keep/` its own history, which keep then commits to as it saves.
4. Once the user confirms, copy the templates from `${CLAUDE_SKILL_DIR}/../../templates/` and fill them in: `FEATURE.md` (plus `DECISIONS.md` when decisions go there) into `${CLAUDE_PROJECT_DIR}/.keep/<feature>/` for a new feature, and `CONTEXT.md`, `STATE.md` and `NOTES.md` into `${CLAUDE_PROJECT_DIR}/.keep/<feature>/<track>/`. Delete any template line you can't fill instead of leaving its placeholder. For the git choices the user accepted, run `bash "${CLAUDE_SKILL_DIR}/../../scripts/setup-git.sh" "${CLAUDE_PROJECT_DIR}"` followed by `ignore`, `history` or both. Then bind it and continue under "Once bound".

**Once bound:**
1. Read `${CLAUDE_PROJECT_DIR}/.keep/<feature>/FEATURE.md`, then the track's `CONTEXT.md` and `STATE.md` (Inbox first), then every file the first two list under "Read on start". If one doesn't exist yet, say so and continue. If FEATURE.md names source docs and there's no `DIGEST.md` yet, suggest `/keep:digest <feature>` once.
2. Check what changed since the state was written: `bash "${CLAUDE_SKILL_DIR}/../../scripts/freshness.sh" "${CLAUDE_PROJECT_DIR}" "<feature>/<track>" "$PWD"`. Treat what STATE.md says about those repos as unconfirmed until you've checked it.
3. For the rest of this chat, work only within this track. Keep its STATE.md current, and record each decision as soon as it's made, where FEATURE.md says decisions go; a hook reminds you after edits and research.
4. If this chat already had work in it before the binding, offer to run `/keep:save` now, so what the chat already knows reaches the track instead of only what happens next.
5. If the user asked for something that isn't done yet, after the name or in the message that led to this track, carry on with it. A ticket still starts the way `/keep:next` does: propose it with its plan, and write no code until the user approves. Otherwise reply with three lines: where things stand, what's in the Inbox and what changed in the repos, and the suggested next step. Then wait.
