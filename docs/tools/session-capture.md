---
layout: page
title: Session Capture
description: OpenCode plugin that auto-promotes learnings to memory before compaction.
nav_section: docs
---

Session Capture — Automatic Memory Promotion

An OpenCode plugin that fires after every completed agent turn and on explicit wrap-up.
Promotes session learnings to the vault's `brain/` notes and Ogham automatically.

- Fires after every agent turn; throttled to at most once per 30 minutes
- Say *"wrap up"* for a full capture pass at any time
- Watermark-based — no duplicate entries across concurrent agents

**Type:** Built-in OpenCode plugin (`src/plugins/session-capture.js`)
