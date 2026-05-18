---
tags: [bootstrap, session, memory]
description: Memory skill guide — when to use each skill during a session
---

## Session — Memory Skills

### While working:

Recall from memory often:
Every time you find a problem/bug that you need to solve,
search your memory using the skill `telamon.recall-memories`
to find previous analysis and solutions for that problem.

Use the `telamon.memory-management` when working with memories.

Use `telamon.thinking` for scratch files, drafts, and WIP notes as needed.

### Before context overflow:
Load the `telamon.remember_checkpoint` skill — saves working state, promotes learnings, then recalls after compaction.

## How memory capture works

Memory storage has one trigger:

- **Post-commit** (automatic) — the `git-hook-remember-session` module installs a `post-commit` hook that 
  fires when a commit is made inside an opencode session (`$OPENCODE_SESSION_ID` is set). 
  The hook runner prompts the agent to run `telamon.remember_session`. The skill scans the conversation since 
  the last watermark and routes findings to the correct latent/ files. 
  Human commits from a normal terminal carry no session ID — the hook exits silently.

## See also

- [[PDRs]]
- [[ADRs]]
- [[global]]
- [[project]]
