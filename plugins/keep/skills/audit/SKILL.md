---
name: audit
description: Review one keep track (the user may call a track a workspace) for repeated facts, contradicted or stale claims, unrecorded decisions and gaps a new chat would hit, and propose fixes. keep starts it on its own at the start of a chat on a track that's due; the user can also ask for it. It reads only and never edits.
context: fork
agent: keep:auditor
---
If `${CLAUDE_PROJECT_DIR}` has no `.keep/` folder, which happens when a chat moves to another folder after it starts, use the nearest folder at or above the current one that has a `.keep/` wherever this says `${CLAUDE_PROJECT_DIR}`.

Track: $ARGUMENTS (as `<feature>/<track>`)

1. Read `${CLAUDE_PROJECT_DIR}/.keep/<feature>/FEATURE.md`, then the track's `CONTEXT.md`, `STATE.md` and `NOTES.md`, the feature's `DECISIONS.md` if it has one, and the other tracks' `CONTEXT.md` in the same feature. If you can read them, also read the user's saved memory notes for this project: the `memory/` folder under `~/.claude/projects/` whose name is the project folder's path with every `/` turned into `-`.
2. Look for:
   - the same fact written twice, even in different words: in `STATE.md` and `NOTES.md`, in two tracks, or in a memory note and a track file;
   - claims in `STATE.md` that the other files or the source docs contradict. Check only what you can confirm by reading; say "unverified" otherwise;
   - decisions mentioned in `STATE.md` or `NOTES.md` that aren't recorded where `FEATURE.md` says decisions go;
   - rules repeated in several tracks' `CONTEXT.md` that belong in `FEATURE.md`;
   - what a new chat would still miss: a vague Next step, a ticket without an acceptance check, an open question with no owner;
   - for a `NOTES.md` over 15 KB that's listed under "Read on start": a summary of at most about 1,500 bytes for the top of that file, with its text, so the track can load the summary instead of the whole file.
3. Return at most 15 items, most useful first. For each: the file and section, what's wrong, the exact edit, and whether it's **lossless** (it only moves or de-duplicates text, or adds a summary, without changing what any line says) or **needs the user** (it drops, rewords or decides something). Don't edit any file.
4. End with this line for the main chat: Next: apply the lossless items; write the others to the track's `review-<date>.md` (or "Nothing needs the user."; writing the file marks the review as handled), with an Inbox line pointing to it when it has items; commit the keep folder if it's its own git repo; show the user the others once, at a natural pause.
