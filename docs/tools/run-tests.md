---
layout: page
title: Pre-Commit Test Gate
description: Git pre-commit hook that runs `make test DRY_RUN=--dry-run` before opencode-driven commits.
nav_section: docs
---

Pre-Commit Test Gate — Block Broken Commits from Opencode Sessions

A git pre-commit hook that runs `make test DRY_RUN=--dry-run` and aborts the commit if tests fail. Only gates commits originating from inside an opencode session — human commits from a normal terminal pass through untouched.

- Fires on `git commit` — only when `$OPENCODE_SESSION_ID` is set (exported by the [session-id-export](plugins) plugin on every tool call)
- Manual commits from a normal terminal are never blocked
- If `make` is not installed, or no `Makefile` exists, or no `test` target is defined → skips with a short notice and lets the commit through
- If `make test DRY_RUN=--dry-run` exits non-zero → captures the output, prints it to stderr, and aborts the commit so the LLM can read the failure and react
- If `make test DRY_RUN=--dry-run` exits zero → silent, commit proceeds

**Why opencode-only?** The LLM tends to claim "done" on the strength of a developer subagent's word. Gating commits ensures a green test suite is a precondition for a recorded commit, removing one class of false-completion.

**Type:** Git pre-commit hook (`src/modules/git-hook-run-tests/run-tests-hook-runner.sh`)
