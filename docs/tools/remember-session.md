---
layout: page
title: Session Capture
description: Git post-commit hook that captures session learnings to memory.
nav_section: docs
---

Session Capture — Automatic Memory Capture on Commit

A git post-commit hook that captures session learnings to the vault's `latent/` notes.

- Fires on `git commit` — only when the commit was made from inside an opencode session
- Targets the originating session by ID (read from `$OPENCODE_SESSION_ID`, exported by the [session-id-export](plugins) plugin on every tool call)
- Manual commits from a normal terminal carry no `OPENCODE_SESSION_ID` → the hook exits silently (no capture, no cross-session pollution)
- Watermark-based — only captures learnings since last watermark
- Silent by default — auto-captures produce no user-facing output; if work was paused mid-workflow the agent silently resumes the next step after capturing
- Say *"wrap up"* for a manual capture with a visible report

**Type:** Git post-commit hook (`src/modules/git-hook-remember-session/remember-session-hook-runner.sh`)
