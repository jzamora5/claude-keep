# Changelog

## 0.4.0 · 2026-10-21

- `/keep:start` takes a single name when only one track matches it: a feature with one track, or a track name used by only one feature. The index and the listings show the shortest command for each track.
- In a chat that isn't bound yet, the agent's first reply names the track that matches what you asked about, with its start command. It only suggests; nothing is bound until you run the command.
- Binding a chat that already has work in it offers `/keep:save`, so what the chat knew before reaches the track.

## 0.3.1 · 2026-10-20

- Edits to Claude's own files under `~/.claude/` (memory, plans, settings) no longer mark the chat dirty.
- Only keep's own `doc-expert` subagent is exempt from the gate; another plugin's agent with a similar name counts as research.
- Saving the state no longer hashes the contents of untracked files, so a large untracked file can't slow the hooks. Freshness still reports an untracked file that changed after the last save.
- The index writes its temporary file inside `.keep/.state/`, so a run that's killed midway can't leave a file for git to pick up.

## 0.3.0 · 2026-10-20

**Breaking:** `KEEP_FOLDER` is removed. The keep folder is always `.keep/` in the project root; a setup that used another folder falls back to `.keep/` without a warning. To keep your tracks, rename that folder to `.keep`.

- Edits inside Claude Code worktrees (`.claude/worktrees/`) mark the chat dirty.
- Skills run their commands from the project root instead of the working directory.
- Freshness reports a reset to an older commit and changes to files that were already uncommitted.
- Chats side by side no longer collide on temporary files.
- `/keep:start <feature>` with a single track uses that track in the skill too, as the bind hook does.
- The Stop hook answers with Stop hook feedback instead of an error.
- Git stamps move to `.keep/.state/` and are removed when a track is closed.
- In a worktree session, the project's own repo is stamped and checked in the worktree.
- The README describes what the gate covers, including its limits.

## 0.2.0 · 2026-10-20

- `.keep/INDEX.md`, generated at every chat start and state save.
- `/keep:list` and `/keep:close`, which archives a track or feature into `.keep/_archive/`.
- `/keep:start` asks you to approve a name before creating a feature or track.
- Idle tracks are flagged after 14 days, and old session files are cleared after 30.

## 0.1.0 · 2026-10-20

- First version: features and tracks, the Stop-hook gate, reload after a compaction, git stamps, and `/keep:start`, `/keep:next`, `/keep:done`, `/keep:save` and `/keep:digest`.
