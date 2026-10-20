# claude-keep

Keep an AI coding agent's working state current across chats, organized by feature.

Long chats lose precision, and starting a new one means explaining again where things stand. `keep` is a Claude Code plugin that holds that state in a few Markdown files per feature, makes the agent keep them current as it works, and loads them into every new chat. You stay in control: it never runs work on its own.

## How it works

- **Features and tracks.** Each feature, a body of work with its own source documents, lives in `.keep/<feature>/`. Inside it, each track (tickets, a research topic, reviews) has its own state, so several chats can work on one feature at the same time.
- **Always current.** A hook won't let a turn end until the track's `STATE.md` is updated, whenever the chat edited files or did research.
- **Picks up where it stopped.** A new chat, `/clear` or a compaction reloads the feature and the track. The state is stamped with each repo's commit, so the next chat sees what changed since.
- **Decisions travel.** A decision that affects another track goes into that track's Inbox.

## Status

Early work in progress; not ready to install yet.
