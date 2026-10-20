# Live checklist

Manual checks in a real session, after the hook tests (`bash tests/hooks.test.sh`) pass. Run them in the Claude desktop app first, then in VS Code.

## Setup

Use a sandbox project with two small git repos (`api/`, `web/`), a design doc (`docs/spec.md`) and a feature in `.keep/demo/` with two tracks, `tickets` and `research`. Install keep for that project only, from a local clone:

```bash
claude plugin marketplace add /path/to/claude-keep --scope project
```

```bash
claude plugin install keep@claude-keep --scope project
```

Open a new session in the sandbox folder and accept the folder trust prompt if it appears. After editing the plugin, run `/reload-plugins`.

## Checks

| # | Do | Expect |
| --- | --- | --- |
| 1 | In a new chat, ask "Which keep tracks exist?" | It answers from the start-of-chat context without reading files: `demo/research` and `demo/tickets` |
| 2 | `/keep:start demo/tickets` | The chat is renamed `demo/tickets`, and it replies with three lines: state, Inbox and repo changes, next step |
| 3 | `/keep:next` | It proposes T-1 with a plan, files and acceptance check, and waits; no code yet |
| 4 | Approve T-1 | It edits `api/app.js`, then gets Stop hook feedback and updates `STATE.md` before the turn ends; `.keep/.state/stamp-demo@tickets` appears |
| 5 | Commit in `api/` (`git -C api commit -am "T-1"`), then `/clear` and ask "What changed since the state was saved?" | It reports `api (main): 1 new commit(s)` with the subject |
| 6 | Ask it to look something up on the web | It updates `STATE.md` before finishing the turn |
| 7 | `/compact`, then `/compact` again | After the second one it asks for `/keep:save` and a fresh chat |
| 8 | `/keep:save` | `STATE.md` is updated with `[verified]`/`[assumed]` marks and a concrete next step, and `.keep` gets a commit |
| 9 | `/keep:digest demo` | `.keep/demo/DIGEST.md` exists and starts with "Built from docs/spec.md" |
| 10 | Ask "Can codes stack? Ask doc-expert." | It cites D-001 and the rejected option (stacking) |
| 11 | In a second chat, `/keep:start demo/research`, then settle Q-1 | A new entry in `DECISIONS.md` with rejected options, and an Inbox line in `demo/tickets` if it affects tickets |
| 12 | Reopen the first chat later (resume) | It's still bound to `demo/tickets` |
| 13 | Fork a bound chat | Note which happens: the fork is told no track is bound, or it keeps the chat title and is rebound to the same track, which leaves two chats on one track |
| 14 | `/keep:list` | It shows `.keep/INDEX.md`: each track, its current work, its last update and its start command |
| 15 | `/keep:start` with no arguments, then ask for a new track | It proposes a name and waits for your OK, then creates the track and prints its start command; INDEX.md lists it |
| 16 | `/keep:close demo/research` | It lists what's still open and asks where each item goes, then moves the track into `.keep/_archive/`, unbinds its chats and commits `.keep` |

Write down anything that differs, with the exact output.
