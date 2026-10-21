---
name: digest
description: Create or refresh a keep feature's DIGEST.md, a 1–2 page summary of its source docs that every track reads at start. Reads the full source docs in a separate context. Run as /keep:digest <feature>.
context: fork
agent: general-purpose
background: false
---
If `${CLAUDE_PROJECT_DIR}` has no `.keep/` folder, which happens when a chat moves to another folder after it starts, use the nearest folder at or above the current one that has a `.keep/` wherever this says `${CLAUDE_PROJECT_DIR}`.

Feature: $ARGUMENTS

1. Read `${CLAUDE_PROJECT_DIR}/.keep/<feature>/FEATURE.md` for the source docs and where decisions are recorded. If either is missing, say so and stop.
2. Read the decisions first, then the source docs in full. Newer decisions override older sections.
3. Write `${CLAUDE_PROJECT_DIR}/.keep/<feature>/DIGEST.md`, at most about 1,200 words. Its first line is `Built from <path> at <hash of the last commit that touched it, or its modification date> on <today's date>.`, one per source doc. Then:
   1. Purpose (2–3 sentences)
   2. Phases (mark the current one)
   3. Architecture at a glance
   4. Data model (names exactly as in the source docs)
   5. Invariants that must never break
   6. Contracts code must match (APIs, events, interfaces)
   7. Non-goals
   8. Section map: each heading of the source docs and one line on what's in it
   9. Open questions: every ambiguity, contradiction or unknown. Never resolve one by guessing.
4. Facts only. Don't edit any other file.
5. Return the word count, the open questions, and any contradictions you found, so the user can review the digest.
