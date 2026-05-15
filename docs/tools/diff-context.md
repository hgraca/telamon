---
layout: page
title: Diff Context
description: Retired experiment — was an OpenCode plugin that injected git change summary at session start.
nav_section: docs
---

# Diff Context — Retired

**Status:** Retired experiment. Moved to a single context priming tool used at the start of each session.

**Type:** Was a built-in OpenCode plugin (`src/instructions/plugins/diff-context.js`)

## What it did

Injected a summary of recent git changes (commits + diffstat) on the first bash tool call of each session.

- Read the remember-session watermark to know which changes were new since the last session
- Budget-capped: max 30 commit lines + 20 diffstat lines

## Reasoning

Context injection at session start is better handled by a single, unified context priming tool rather than multiple independent plugins. This reduces complexity and ensures consistent priming across all context sources.

## Source

Removed from the codebase. Available in git history at `src/instructions/plugins/diff-context.js`.
