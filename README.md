# claude-keep

Keep an AI coding agent's working state current across chats, organized by feature.

## The problem

Long agent chats lose precision as they fill up and get compacted, so you start fresh ones. Each new chat then needs a briefing: what's half-done, on which branch, what's failing, what was decided and what was ruled out, what's waiting on someone else, and what comes next. Writing that handoff by hand is tedious, and it's written at the end, from the same context that was losing precision.

It's harder when you own a whole feature rather than one ticket. The build, research for later phases and reviews all rest on the same source docs, and the plan keeps changing as vendors, stakeholders and the implementation turn up new facts. That work runs across many chats, side by side and for weeks.

## How keep is different

**From spec-driven tools** such as OpenSpec or Spec Kit. They solve another layer: agreeing on *what to build* before code is written, and tracking which tasks are done. keep covers the *work in progress*: where each line of work stands right now, kept current while you work. The two fit together, and a feature can plan its tickets with OpenSpec.

**From session handoff tools**, which write a summary when you ask for one, at the end of a session or just before a compaction, for one session or one repo:

- **It's enforced, not remembered.** When a chat edits files or does research, a hook sends it back to update the state when the turn ends, at most once every 15 minutes. Nothing depends on the agent remembering, or on you running a command before you stop. [What the gate covers](#what-the-gate-covers) has the details.
- **It's organized by feature, with tracks.** Several chats can work on one feature at once (tickets, a research topic, reviews), share its source docs, and pass decisions to each other through an Inbox.
- **It's checked against reality.** Each save stamps the feature's repos with their commits, so the next chat sees what changed since (new commits, a different branch, uncommitted files) before it trusts the state.

Everything is plain Markdown in your project, and the hooks make no network or model calls. You stay in control: keep never starts work on its own, and every ticket and every code commit waits for your approval. If you give `.keep/` its own history, keep commits the state there as it saves.

## How it works

- **Files.** A feature lives in `.keep/<feature>/` with a `FEATURE.md` that points to its source docs (an RFC, PRD, design doc or spec) instead of copying them. Each track (call it a workspace if you like; the agent understands both words) has a `CONTEXT.md` (what it's for), a `STATE.md` (where it stands) and a `NOTES.md` (reference).
- **Start.** In a new chat, say what you want to work on. When a message starts work (not a quick question), the agent names the matching track, or offers to create one, and asks once whether to keep the work there; say yes and it carries on with your request. Nothing is bound or created until you agree. A ticket still waits for your approval of its plan. You can also type `/keep:start <feature>/<track>`, always with the full name, and your request after it: `/keep:start legal/terms check the new vendor doc`. A chat you haven't named is named after its track; a chat you named keeps its name, and keep remembers which track that name is on. Either way, `/clear`, a resume or a compaction then reloads the feature and the track by themselves. A name you give a chat partway through is picked up at its next start or `/clear`, and two chats with the same name share one remembered track, the most recent.
- **Opt in mid-chat.** keep does nothing in a chat until you bind it, so an ongoing chat can opt in at any point: ask the agent to work on a track or to save the chat to keep, or type `/keep:start`. If no track fits, the agent proposes a new track, in an existing feature when one fits. When you bind a chat that already has work in it, the agent offers `/keep:save` so what the chat already knows reaches the track.
- **Stays under the limit.** Hook output over 10,000 characters reaches Claude only as a short preview, so the reload always includes the Inbox, Current and Next step, adds whole sections while they fit, and names the ones it left out.
- **Decisions.** Each decision is recorded when it's made, with the options it rejected and why, so a later chat doesn't propose them again. The save reminder asks for any decision not recorded yet.
- **You always know what exists.** `.keep/INDEX.md` is regenerated at every chat start and every state save: each track, its current work (or its goal when nothing is in flight), its last update and the command to start it. A new track is proposed in one message, with its name, its goal and, for a new feature, the repos and settings the agent found; nothing is created until you confirm or correct it.
- **Kept tidy on its own.** After every save, at every chat start and right after a chat is bound, a quick check flags what would trip up a new chat:
  - `STATE.md` over its size, an empty Next step, unmarked Current lines, and tickets without an acceptance check;
  - leftover template placeholders, and files listed to read that don't exist or are large;
  - lines copied into both state and notes, and Inbox items older than two weeks.

  The check is a few text scans of small files, skipped when nothing changed that day, and each issue is raised once. The agent fixes what only moves, de-duplicates or fills in text in the same save, and asks you about the rest once per chat, at a natural pause.
- **A deep review when a track is due.** When a track's notes grow by 10 KB, or two weeks pass with changes, the next chat on that track starts `/keep:audit` in the background on Sonnet, so the result lands in a chat that's still open. It reads the track and your saved memory notes for this project, then proposes merges, contradictions to fix, decisions to record, and a short summary to load instead of large notes. Lossless edits are applied without asking; the rest waits for you in the track's `review-<date>.md`, with an Inbox line pointing to it. A review counts as done only once that file is written, so a result lost to `/clear` is retried an hour later.
- **Cleanup is one command.** `/keep:close` hands off what's still open, then moves the track or feature into `.keep/_archive/` and unbinds its chats; the track's own files are never deleted. Tracks untouched for 14 days are flagged as idle, and runtime files of old sessions are cleared after 30 days.

## What the gate covers

- **Counted:** edits with Edit, Write and NotebookEdit to files in the project folder, including Claude Code worktrees under `.claude/worktrees/`; web fetches and searches; and subagents, except keep's `doc-expert`, which only reads the feature's own source docs. Edits inside `.keep/`, to the project's own `.claude/` settings, and to files outside the project folder, such as scratch files and Claude's files in `~/.claude/` (memory, plans), aren't counted.
- **Not counted:** files changed through shell commands (`sed -i`, code generators, `git checkout`). Run `/keep:save` after work like that.
- **How hard it pushes:** at the end of a turn after counted work, the Stop hook sends the chat back to update Current and Next step in STATE.md and record any new decision, as Stop hook feedback rather than an error. It asks at most once every 15 minutes after this chat's last save; another chat editing the same STATE.md, for example to add an Inbox line, doesn't reset that clock. So a chat's first working turn saves, and after that a chat that ends loses at most the last 15 minutes of reasoning; its code changes still show up in the next chat's freshness check. Once that time has passed, it asks at the end of every turn until the state is saved, even a turn that only answered a question. `KEEP_SAVE_MINUTES=0` asks after every working turn.
- **Worktree sessions:** freshness checks the worktree the session works in. In a `--worktree` or `EnterWorktree` session, Claude Code blocks edits to the main checkout, so if `.keep/` is inside the repo the worktree came from, the chat can read its track but can't save it. keep doesn't ask it to, and the agent says so in its first reply. Keep `.keep/` in a folder above your repos, or work on the track from a session in the main checkout.

## Commands

You only need `/keep:start`, or just say what you want to work on. The agent brings up the others when they're due: `/keep:save` at the compaction limit and when a chat opts in midway, `/keep:digest` when a feature has source docs but no digest, and `/keep:close` appears next to idle tracks.

| Command | What it does |
| --- | --- |
| `/keep:start <feature>/<track>` | Binds the chat to a track, and names the chat after it unless you named the chat yourself; it takes only the full name, and your request can follow it. The agent runs it too, once you agree to a track it suggested. Without a name, lists the tracks, or proposes a new one and creates it once you confirm. `/keep:start off` unbinds the chat. A chat with unsaved work on one track saves it before switching to another |
| `/keep:current` | Shows which track this chat is on, with its current work, next step and start command, or says it isn't bound |
| `/keep:list` | Shows every track with its current work or goal, its last update and the command to start it |
| `/keep:next` | Proposes the next ticket with a short plan, and waits for your approval before any code |
| `/keep:done` | Verifies the ticket and updates the feature's docs; after your approval, commits and marks the ticket done in the state. A failed check stops it |
| `/keep:save` | Saves the state for the next chat, before `/clear` or when stopping. In a chat that isn't bound yet, it asks which track first |
| `/keep:rename <feature>[/<track>] <new name>` | Renames a track within its feature, or a whole feature. Every reference to it in `.keep/` is updated, and the agent updates the project's `CLAUDE.md` files and its saved notes too, without questions. Its chats stay bound, and the ones named after the track get the new name at their next message. The agent runs it too when you ask |
| `/keep:audit <feature>/<track>` | Runs the deep review of a track now. keep starts it on its own when a track is due |
| `/keep:close <feature>[/<track>]` | Hands off what's still open, then archives the track or the whole feature. The agent runs it too when you ask it to close one |
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

The keep folder is always `.keep/` in the project root. A chat that moves to another folder after it starts keeps the project root it started in; when that has no `.keep/`, keep uses the nearest one at or above the folder the chat works in. The git stamps describe this machine's checkouts, so they live in `.state/` and never travel with the state. Freshness leaves `.keep/` out when it checks a repo, so the state's own files never count as code changes. When it creates `.keep/`, the agent offers two separate choices: keeping `.keep/` out of the project's git, through the local exclude file that isn't shared, and giving `.keep/` its own history, which keep then commits to as it saves. These environment variables change the defaults:

| Variable | Default | What it sets |
| --- | --- | --- |
| `KEEP_SAVE_MINUTES` | 15 | Minutes between the Stop hook's requests to update STATE.md; 0 asks after every working turn |
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

Then type `/keep:start` in your project and describe what you're working on: the agent proposes the first track. After that, it offers the right track whenever a chat starts work.

keep's skills run their own scripts without asking. Saving STATE.md outside a skill, when the reminder asks for it, is a normal file edit, so with default permissions it asks each time. To allow edits to `.keep/` in a project, add this to its `.claude/settings.json`:

```json
{
  "permissions": { "allow": ["Edit(/.keep/**)"] }
}
```

## Status

Version 0.9.0, early ([changelog](CHANGELOG.md)). The hooks and scripts are tested with simulated hook inputs (`bash tests/hooks.test.sh`) on macOS's bash 3.2, and ten behaviors are checked in real headless sessions with `claude plugin eval` (`bash tests/evals.sh`, cases in `plugins/keep/evals/`). `tests/live-checklist.md` lists the checks that still need a person: several messages in a row, `/clear`, resume, compaction and the app's permission prompts.

## Credits

Ideas borrowed from other handoff tools: verified versus assumed state and dead ends ([blader/baton](https://github.com/blader/baton)), a commit stamp and a next step that names a file ([Dereknalox123/claude-code-baton](https://github.com/Dereknalox123/claude-code-baton)), binding a session to a named workstream ([mattpollak/relay](https://github.com/mattpollak/relay)), naming what a reload left out ([nickthelegend/loom](https://github.com/nickthelegend/loom)), the decision format ([EdytaKucharska/keel](https://github.com/EdytaKucharska/keel)), writing rules for checkpoints ([arcAman07/claude-cairn](https://github.com/arcAman07/claude-cairn)), and loading whole sections under the cap ([eugeniughelbur/obsidian-second-brain](https://github.com/eugeniughelbur/obsidian-second-brain)). The approach follows Anthropic's [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents).

## License

MIT. See [LICENSE](LICENSE).
