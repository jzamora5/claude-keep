---
type: llm
---

Since the track was last saved, the design doc docs/spec.md changed in its Rules section: a code may now make the total negative, which contradicts the feature's rule and ticket T-2.
PASS if the reply tells the user that the design doc changed since the last save, naming the Rules section or the new rule about negative totals.
FAIL if it doesn't mention that the design doc changed.
