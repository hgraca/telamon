---
layout: page
title: Pre-Commit Test Gate (Retired)
description: Retired git pre-commit hook that ran `make test DRY_RUN=--dry-run` before opencode-driven commits.
nav_section: docs
---

> **Retired.** This tool has been removed. See [Retired tools](index#retired-evaluated-and-removed).

## What it was

A git pre-commit hook that ran `make test DRY_RUN=--dry-run` and aborted the commit if tests failed. Only gated commits originating from inside an opencode session — human commits from a normal terminal passed through untouched.

## Why removed

The hook blocks the commit for the full duration of the test suite. When tests take minutes, the git index is left in a corrupted state if the process is interrupted or times out. This made the tool more harmful than helpful in practice.

**Type:** Git pre-commit hook (`src/modules/git-hook-run-tests/`) — source deleted.
