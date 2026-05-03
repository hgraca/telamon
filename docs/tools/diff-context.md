---
layout: page
title: Diff Context
description: OpenCode plugin that injects git change summary at session start.
nav_section: docs
---

Diff Context — Session-Aware Git Change Summary

An OpenCode plugin that injects a summary of recent git changes (commits + diffstat) on the first bash tool call of each session.

- Automatic — fires on the first bash call
- Reads the remember-session watermark to know which changes are new since the last session
- Budget-capped: max 30 commit lines + 20 diffstat lines

**Type:** Built-in OpenCode plugin (`src/plugins/diff-context.js`)
