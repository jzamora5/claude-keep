# claude-keep

Keep an AI coding agent's working state current across chats, organized by feature.

## The problem

Long agent chats lose precision as they fill up and get compacted, so you start fresh ones. Each new chat then needs a briefing: what's half-done, on which branch, what's failing, what was decided and what was ruled out, what's waiting on someone else, and what comes next. Writing that handoff by hand is tedious, and it's written at the end, from the same context that was losing precision.

It's harder when you own a whole feature rather than one ticket. The build, research for later phases and reviews all rest on the same source docs, and the plan keeps changing as vendors, stakeholders and the implementation turn up new facts. That work runs across many chats, side by side and for weeks.

## How keep is different

**From spec-driven tools** such as OpenSpec or Spec Kit. They solve another layer: agreeing on *what to build* before code is written, and tracking which tasks are done. keep covers the *work in progress*: where each line of work stands right now, kept current while you work. The two fit together, and a feature can plan its tickets with OpenSpec.

**From session handoff tools**, which write a summary when you ask for one, at the end of a session or just before a compaction, for one session or one repo:

- **It's enforced, not remembered.** When a chat edits files or does research, a hook sends it back to update the state before the turn ends. Nothing depends on the agent remembering, or on you running a command before you stop. [What the gate covers](#what-the-gate-covers) has the details.
- **It's organized by feature, with tracks.** Several chats can work on one feature at once (tickets, a research topic, reviews), share its source docs, and pass decisions to each other through an Inbox.
- **It's checked against reality.** Each save stamps the feature's repos with their commits, so the next chat sees what changed since (new commits, a different branch, uncommitted files) before it trusts the state.

Everything is plain Markdown in your project, and the hooks make no network or model calls. You stay in control: keep never runs work on its own, and every ticket and commit waits for your approval.

## How it works

- **Files.** A feature lives in `.keep/<feature>/` with a `FEATURE.md` that points to its source docs (an RFC, PRD, design doc or spec) instead of copying them. Each track has a `CONTEXT.md` (what it's for), a `STATE.md` (where it stands) and a `NOTES.md` (reference).
- **Start.** `/keep:start <feature>/<track>` binds the chat to a track and names the chat after it. A new chat, `/clear`, a resume or a compaction then reloads the feature and the track by themselves.
- **Stays under the limit.** Hook output over 10,000 characters reaches Claude only as a short preview, so the reload always includes the Inbox, Current and Next step, adds whole sections while they fit, and names the ones it left out.
- **Decisions.** Each decision is recorded with the options it rejected and why, so a later chat doesn't propose them again.
- **You always know what exists.** `.keep/INDEX.md` is regenerated at every chat start and every state save: each track, its current work, its last update and the command to start it. New features and tracks get a name you approve before they're created.
- **Cleanup is one command.** `/keep:close` hands off what's still open, then moves the track or feature into `.keep/_archive/` and unbinds its chats; the track's own files are never deleted. Tracks untouched for 14 days are flagged as idle, and runtime files of old sessions are cleared after 30 days.

## What the gate covers

- **Counted:** edits with Edit, Write and NotebookEdit to files in the project, including Claude Code worktrees under `.claude/worktrees/`; web fetches and searches; and subagents, except `doc-expert`, which only reads the feature's own source docs. Edits inside `.keep/` and to the project's own `.claude/` settings aren't counted.
- **Not counted:** files changed through shell commands (`sed -i`, code generators, `git checkout`). Run `/keep:save` after work like that.
- **How hard it pushes:** the Stop hook sends the chat back once per turn, as Stop hook feedback rather than an error. If the state still isn't updated, it asks again at the end of the next turn, even one that only answered a question, until the state is saved.
- **Worktree sessions:** freshness checks the worktree the session works in. In a `--worktree` or `EnterWorktree` session, Claude Code blocks edits to the main checkout, so if `.keep/` is inside the repo the worktree came from, the state can't be updated from there. Keep `.keep/` in a folder above your repos, or save from a session in the main checkout.

## Commands

| Command | What it does |
| --- | --- |
| `/keep:start <feature>/<track>` | Binds the chat to a track and names the chat after it; without arguments, lists the tracks or creates a new one after you approve its name |
| `/keep:list` | Shows every track with its current work, its last update and the command to start it |
| `/keep:next` | Proposes the next ticket with a short plan, and waits for your approval before any code |
| `/keep:done` | Verifies the ticket, updates the feature's docs and the state, and commits after your approval |
| `/keep:save` | Saves the state for the next chat, before `/clear` or when stopping |
| `/keep:close <feature>[/<track>]` | Hands off what's still open, then archives the track or the whole feature |
| `/keep:digest <feature>` | Builds a 1–2 page digest of the feature's source docs in a separate context |

The `doc-expert` subagent answers questions from the source docs, so a chat never has to load them whole.

## Files

```text
.keep/
  INDEX.md           generated list of tracks, ignored by git
  <feature>/
    FEATURE.md       goal, source docs, where decisions go, repos, rules
    DIGEST.md        optional, built by /keep:digest
    DECISIONS.md     optional, when decisions aren't recorded in a source doc
    <track>/
      CONTEXT.md     what the track is for
      STATE.md       Inbox, Current, Next step, Tickets, Done log, Dead ends, Gotchas, Open questions
      NOTES.md       reference, read on demand
  _archive/          closed tracks and features
  .state/            runtime files and each track's git stamp, ignored by git
```

The keep folder is always `.keep/` in the project root. The git stamps describe this machine's checkouts, so they live in `.state/` and never travel with the state. These environment variables change the defaults:

| Variable | Default | What it sets |
| --- | --- | --- |
| `COMPACT_LIMIT` | 2 | Compactions before the agent suggests saving and starting a fresh chat |
| `KEEP_IDLE_DAYS` | 14 | Days without a state update before a track is flagged as idle |
| `KEEP_STATE_DAYS` | 30 | Days before runtime files of old sessions are cleared |

## Install

Requires bash, `jq` and `git`.

```bash
claude plugin marketplace add jzamora5/claude-keep
```

```bash
claude plugin install keep@claude-keep
```

To use it in one project only, add this to that project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "claude-keep": { "source": { "source": "github", "repo": "jzamora5/claude-keep" } }
  },
  "enabledPlugins": { "keep@claude-keep": true }
}
```

## Status

Version 0.3.0, early. The hooks and scripts are tested with simulated hook inputs (`bash tests/hooks.test.sh`) on macOS's bash 3.2; they haven't run in a live session yet. `tests/live-checklist.md` lists the checks for a real session.

## Credits

Ideas borrowed from other handoff tools: verified versus assumed state and dead ends ([blader/baton](https://github.com/blader/baton)), a commit stamp and a next step that names a file ([Dereknalox123/claude-code-baton](https://github.com/Dereknalox123/claude-code-baton)), binding a session to a named workstream ([mattpollak/relay](https://github.com/mattpollak/relay)), naming what a reload left out ([nickthelegend/loom](https://github.com/nickthelegend/loom)), the decision format ([EdytaKucharska/keel](https://github.com/EdytaKucharska/keel)), writing rules for checkpoints ([arcAman07/claude-cairn](https://github.com/arcAman07/claude-cairn)), and loading whole sections under the cap ([eugeniughelbur/obsidian-second-brain](https://github.com/eugeniughelbur/obsidian-second-brain)). The approach follows Anthropic's [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents).

## License

MIT. See [LICENSE](LICENSE).
