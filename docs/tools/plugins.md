---
layout: page
title: Plugins
description: OpenCode plugins that extend agent capabilities.
nav_section: docs
---

Plugins are OpenCode extensions that run automatically. They fire on specific events (session start, agent turn, bash call) to inject context or capture knowledge.

| Plugin                                        | What it does                                                                                                      | Source                                                                                                     |
|-----------------------------------------------|-------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------|
| [Status Marker Enforcer](agent-communication) | Nudges stalled agent turns to emit a terminal status marker (`FINISHED!`, `BLOCKED:`, `NEEDS_INPUT:`, `PARTIAL:`) | [`agent-communication.js`](https://github.com/hgraca/telamon/blob/main/src/instructions/plugins/agent-communication.js) |
| [Diff Context](diff-context)                  | Injects git change summary on first bash call                                                                     | [`diff-context.js`](https://github.com/hgraca/telamon/blob/main/src/instructions/plugins/diff-context.js)               |
| [Graphify](graphify)                          | Injects god nodes and communities at session start                                                                | [`graphify.js`](https://github.com/hgraca/telamon/blob/main/src/instructions/plugins/graphify.js)                       |
| [RTK](rtk)                                    | Compresses bash output before it reaches the LLM                                                                  | [`rtk.ts`](https://github.com/hgraca/telamon/blob/main/src/instructions/plugins/rtk.ts)                                 |
| RTK Dedupe                                    | Deduplicates repeated output chunks from RTK                                                                      | [`rtk-dedupe.ts`](https://github.com/hgraca/telamon/blob/main/src/instructions/plugins/rtk-dedupe.ts)                   |
| [Active Work Context](active-work-context)    | Injects active work items at session start, prompts user to continue/archive/start new                            | [`active-work-context.js`](https://github.com/hgraca/telamon/blob/main/src/instructions/plugins/active-work-context.js) |

Plugin source code lives in [`src/instructions/plugins/`](https://github.com/hgraca/telamon/tree/main/src/plugins).
