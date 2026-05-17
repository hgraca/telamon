---
tags: [bootstrap, session, memory]
description: Memory skill guide — when to use each skill during a session
---

## Session — Memory Skills

### While working:

Use the `telamon.memory-management` when working with memories.

Use `telamon.recall-memories` specifically to recall memories of past experiences/sessions about a subject.

No manual memory triggers needed. The remember-session plugin fires `telamon.remember_session` automatically on idle.

Use `telamon.thinking` for scratch files, drafts, and WIP notes as needed.

### Before context overflow:
Load the `telamon.remember_checkpoint` skill — saves working state, promotes learnings, then recalls after compaction.

### Manual wrap-up (optional):
Say "wrap up" to trigger an immediate capture via `telamon.remember_session` — produces a report of what was saved.

## How memory capture works

Memory storage has exactly **two triggers**:

1. **Idle** (automatic) — the remember-session plugin detects `session.idle`, checks the lock file and last-message origin to prevent loops, then prompts the agent to run `telamon.remember_session`. The skill scans the conversation since the last watermark and routes findings to the correct latent/ files.

2. **Checkpoint** (before compaction) — `telamon.remember_checkpoint` saves working state before context overflows.

## See also

- [[PDRs]]
- [[ADRs]]
- [[global]]
- [[project]]
