---
type: llm
focus: trace
---

The track's STATE.md and NOTES.md both contain the same Done-log line about T-0, and its Next step is empty.
PASS if the review's result (in the reply or the trace) lists proposed fixes, labels them as lossless or needing the user, and includes the duplicated T-0 line or the empty Next step.
FAIL if it edits files, or if no list of proposed fixes appears anywhere in the trace.
