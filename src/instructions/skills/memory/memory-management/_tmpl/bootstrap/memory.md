---
tags: [bootstrap, session, memory]
description: Memory skill guide — when to use each skill during a session
---

## Session — Memory Skills

### Session start (mandatory):
Load the `telamon.recall_memories` skill — recalls past context, reads brain/ notes, initializes knowledge tools.

### While working:
No manual memory triggers needed. The remember-session plugin fires `telamon.remember_session` automatically on idle.

Use `telamon.thinking` for scratch files, drafts, and WIP notes as needed.

### Before context overflow:
Load the `telamon.remember_checkpoint` skill — saves working state, promotes learnings, then recalls after compaction.

### Manual wrap-up (optional):
Say "wrap up" to trigger an immediate capture via `telamon.remember_session` — produces a report of what was saved.

### Switching projects:
Load the `telamon.recall_memories` skill for the new project.

## How memory capture works

Memory storage has exactly **two triggers**:

1. **Idle** (automatic) — the remember-session plugin detects `session.idle`, checks the lock file and last-message origin to prevent loops, then prompts the agent to run `telamon.remember_session`. The skill scans the conversation since the last watermark and routes findings to the correct brain/ files.

2. **Checkpoint** (before compaction) — `telamon.remember_checkpoint` saves working state before context overflows.

## See also

- [[memories]]
- [[PDRs]]
- [[ADRs]]
- [[patterns]]
- [[gotchas]]
