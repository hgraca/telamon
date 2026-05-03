---
layout: page
title: Session Capture
description: OpenCode plugin that captures session learnings to memory on idle.
nav_section: docs
---

Session Capture — Automatic Memory Capture on Idle

An OpenCode plugin that fires on `session.idle` events.
Captures session learnings to the vault's `brain/` notes automatically.

- Fires on idle — only when the agent has finished all work and the session goes quiet
- Loop prevention: lock file (10-min TTL) + last-message check (skips if last user message was a capture prompt)
- Watermark-based — only captures learnings since last watermark
- Say *"wrap up"* for a manual capture with a visible report

**Type:** Built-in OpenCode plugin (`src/plugins/remember-session.js`)
