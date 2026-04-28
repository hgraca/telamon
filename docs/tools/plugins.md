---
layout: page
title: Plugins
description: OpenCode plugins that extend agent capabilities.
nav_section: docs
---

Plugins are OpenCode extensions that run automatically. They fire on specific events (session start, agent turn, bash call) to inject context or capture knowledge.

| Plugin                             | What it does                                                | Source                                                                                             |
|------------------------------------|-------------------------------------------------------------|----------------------------------------------------------------------------------------------------|
| [Session Capture](session-capture) | Promotes learnings to memory after each turn and on wrap-up | [`session-capture.js`](https://github.com/hgraca/telamon/blob/main/src/plugins/session-capture.js) |
| [Diff Context](diff-context)       | Injects git change summary on first bash call               | [`diff-context.js`](https://github.com/hgraca/telamon/blob/main/src/plugins/diff-context.js)       |
| [Graphify](graphify)               | Injects god nodes and communities at session start          | [`graphify.js`](https://github.com/hgraca/telamon/blob/main/src/plugins/graphify.js)               |
| [RTK](rtk)                         | Compresses bash output before it reaches the LLM            | [`rtk.ts`](https://github.com/hgraca/telamon/blob/main/src/plugins/rtk.ts)                         |
| RTK Dedupe                         | Deduplicates repeated output chunks from RTK                | [`rtk-dedupe.ts`](https://github.com/hgraca/telamon/blob/main/src/plugins/rtk-dedupe.ts)           |
| [Script Runner](script-runner)     | Runs shell scripts and passes output to the LLM             | [`script-runner.js`](https://github.com/hgraca/telamon/blob/main/src/plugins/script-runner.js)     |

Plugin source code lives in [`src/plugins/`](https://github.com/hgraca/telamon/tree/main/src/plugins).
