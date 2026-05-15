---
layout: page
title: Plugins
description: OpenCode plugins that extend agent capabilities.
nav_section: docs
---

Plugins are OpenCode extensions that run automatically. They fire on specific events (session start, agent turn, bash call) to inject context or capture knowledge.

| Plugin                                        | What it does                                                                                                      | Source                                                                                                                  |
|-----------------------------------------------|-------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------|
| [Status Marker Enforcer](agent-communication) | Nudges stalled agent turns to emit a terminal status marker (`FINISHED!`, `BLOCKED:`, `NEEDS_INPUT:`, `PARTIAL:`) | [`agent-communication.js`](https://github.com/hgraca/telamon/blob/main/src/instructions/plugins/agent-communication.js) |
| [LLM Logger](llm-logger)                      | Logs every LLM request/response to disk — one file per message, organized by session                              | [`llm-logger.ts`](https://github.com/hgraca/telamon/blob/main/src/instructions/plugins/llm-logger.ts)                   |
| [RTK](rtk)                                    | Compresses bash output before it reaches the LLM                                                                  | [`rtk.ts`](https://github.com/hgraca/telamon/blob/main/src/instructions/plugins/rtk.ts)                                 |
| RTK Dedupe                                    | Deduplicates repeated cli calls wrapped in RTK                                                                    | [`rtk-dedupe.ts`](https://github.com/hgraca/telamon/blob/main/src/instructions/plugins/rtk-dedupe.ts)                   |

Plugin source code lives in [`src/instructions/plugins/`](https://github.com/hgraca/telamon/tree/main/src/plugins).

## Retired experiments

These plugins were evaluated and removed. They remain in git history for reference.

| Plugin                                     | What it did                                                                          | Reasoning                                                                        |
|--------------------------------------------|--------------------------------------------------------------------------------------|----------------------------------------------------------------------------------|
| [Active Work Context](active-work-context) | Injected active work items at session start, prompted user to continue/archive/start | Made the session go off topic. Should be done as part of the memory audit skill. |
| [Diff Context](diff-context)               | Injected git change summary on first bash call                                       | Moved to a single context priming tool, used at the start of each session.       |
| [Graphify](graphify)                       | Injected god nodes and communities at session start                                  | Moved to a single context priming tool, used at the start of each session.       |
