---
layout: page
title: LLM Logger
description: Logs every LLM request/response to disk for debugging and analysis.
nav_section: docs
---

# LLM Logger Plugin

Logs every LLM request and response to disk — one file per message. Uses only the `chat.message` hook, which fires after all streaming deltas have been accumulated into the final message.

## File Layout

```
.ai/telamon/memory/llm-logs/
├── <sessionID>/
│   ├── <timestamp>-request-<messageID>.json    # user prompt
│   ├── <timestamp>-response-<messageID>.json   # assistant response
│   └── ...
└── ...
```

## What's Captured

Each log file contains:

- **Session metadata**: session ID, message ID, agent name, model, provider
- **Message info**: role, token counts, cost, finish reason, errors
- **Parts**: text content, tool calls (name + input), tool results (content + error status)

## Privacy

The log directory lives under `.ai/telamon/` which is gitignored — no prompts or responses leak into version control.

## Source

[`src/instructions/plugins/llm-logger.ts`](https://github.com/hgraca/telamon/blob/main/src/instructions/plugins/llm-logger.ts)