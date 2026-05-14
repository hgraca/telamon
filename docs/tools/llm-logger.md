---
layout: page
title: LLM Logger
description: Logs every LLM request, response, and system prompt to disk for debugging and analysis.
nav_section: docs
---

# LLM Logger Plugin

Logs every LLM request, response, and system prompt to disk — one file per message plus a system-prompt file per session.

## How It Works

The plugin uses two hooks:

1. **`experimental.chat.messages.transform`** — fires before every LLM call with ALL messages in the conversation (both user and assistant). Captures assistant responses from the previous turn alongside the current user message. Deduplicates by message ID so retries and sub-agent calls don't create duplicates.

2. **`experimental.chat.system.transform`** — fires before every LLM call with the system prompt. Captures bootstrap context, instructions, and any other system-level content. Logged once per session (deduplicated by content).

## File Layout

```
.ai/telamon/logs/llm-logger/
├── <YYYYMMDDHHMMSS>-<sessionID>/
│   ├── <timestamp>-request-<messageID>.json      # user prompt
│   ├── <timestamp>-response-<messageID>.json     # assistant response
│   └── <timestamp>-system-prompt.json            # system prompt (once per session)
└── ...
```

## What's Captured

### Message files (request / response)

Each message file contains:

- **Session metadata**: session ID, message ID, agent name, model, provider
- **Message info**: role, token counts, cost, finish reason, errors
- **Parts**: text content, tool calls (name + input), tool results (content + error status)

### System prompt file

The system prompt file contains:

- **Session metadata**: session ID
- **System prompt**: array of system instruction strings (includes bootstrap context, AGENTS.md, and any other instructions)

## Deduplication

- **Messages**: tracked by message ID per session. If the same message appears in multiple hook invocations (e.g., retries, sub-agent calls), it's only logged once.
- **System prompts**: tracked by content per session. If the system prompt doesn't change between invocations, it's not re-logged. If it changes (e.g., different agent context), the new version is logged.

## Privacy

The log directory lives under `.ai/telamon/` which is gitignored — no prompts or responses leak into version control.

## Source

[`src/instructions/plugins/llm-logger.ts`](https://github.com/hgraca/telamon/blob/main/src/instructions/plugins/llm-logger.ts)