---
name: telamon.recall_gotchas
description: "Read brain/gotchas.md in full at session start. Provides awareness of known traps, constraints, 
and recurring bugs before writing code. Use at developer bootstrap."
---

# Recall Gotchas

Read `.ai/telamon/memory/brain/gotchas.md` eagerly at session start to prime awareness of known traps.

## When to Apply

- At developer session start (bootstrap), before writing any code
- When entering a problem area that may have known gotchas
- When the orchestrator delegates a task in a domain with historical traps

## Procedure

### 1. Read gotchas.md in full

Read `.ai/telamon/memory/brain/gotchas.md` completely. 
The file is kept small (< 200 entries) and is always relevant — do not search, read the whole file.

### 2. Hold context

Keep all gotchas in working memory for the duration of the session. When implementing code that touches a 
domain mentioned in a gotcha, apply the documented fix or workaround proactively.

### 3. Flag relevance

If the current task touches a known gotcha area, mention it in your assumptions before starting work:
- "Note: gotcha X applies here — using the documented workaround."
