---
tags: [bootstrap, session, memory]
description: Memory skill guide — when to use each skill during a session
---

## Session — Memory Skills

### While working:

Use the `telamon.memory-management` when working with memories.

Use `telamon.recall-memories` specifically to recall memories of past experiences/sessions about a subject.

No manual memory triggers needed. The git `post-commit` hook fires `telamon.remember_session` automatically after each commit made inside an opencode session.

Use `telamon.thinking` for scratch files, drafts, and WIP notes as needed.

### Before context overflow:
Load the `telamon.remember_checkpoint` skill — saves working state, promotes learnings, then recalls after compaction.

### Manual wrap-up (optional):
Say "wrap up" to trigger an immediate capture via `telamon.remember_session` — produces a report of what was saved.

## How memory capture works

Memory storage has exactly **two triggers**:

1. **Post-commit** (automatic) — the `git-hook-remember-session` module installs a `post-commit` hook that fires when a commit is made inside an opencode session (`$OPENCODE_SESSION_ID` is set). The hook runner prompts the agent to run `telamon.remember_session`. The skill scans the conversation since the last watermark and routes findings to the correct latent/ files. Human commits from a normal terminal carry no session ID — the hook exits silently.

2. **Checkpoint** (before compaction) — `telamon.remember_checkpoint` saves working state before context overflows.

## See also

- [[PDRs]]
- [[ADRs]]
- [[global]]
- [[project]]
