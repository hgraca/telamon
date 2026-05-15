---
layout: page
title: Active Work Context
description: Retired experiment — was an OpenCode plugin that injected active work items at session start.
nav_section: docs
---

# Active Work Context — Retired

**Status:** Retired experiment. Removed because it made the session go off topic. This functionality should be done as part of the memory audit skill instead.

**Type:** Was a built-in OpenCode plugin (`src/instructions/plugins/active-work-context.js`)

## What it did

Injected a summary of active work items into the first bash call of each session. If active tasks existed, the agent would ask the user whether to continue one, archive one, or start something new.

- Scanned `.ai/telamon/memory/work/active/` for task directories
- Extracted task name, title, and short description from each `README.md`

## Reasoning

The plugin's context injection at session start frequently derailed the session's focus. Active work context is better handled on-demand by the memory audit skill, which can present work items in a controlled, user-initiated manner.

## Source

Removed from the codebase. Available in git history at `src/instructions/plugins/active-work-context.js`.
