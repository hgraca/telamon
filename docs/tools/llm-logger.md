---
layout: page
title: LLM Logger
description: Logs every LLM user request to disk for debugging and analysis.
nav_section: docs
---

# LLM Logger Plugin

Logs every user message sent to the LLM to disk — one file per message.

## How It Works

The plugin uses a single hook:

- **`chat.message`** — fires once per user message with the full message body and parts (text, file attachments, agent invocations). Captures the user side of every LLM exchange.

Assistant responses and system prompts are NOT captured by this plugin. opencode v1.14.50's `chat.message` hook is user-message-only, and the `experimental.*` system-prompt hooks crash startup in this opencode version.

## File Layout

```
.ai/telamon/logs/llm-logger/
└── <YYYYMMDDHHMMSS>-<sessionID>/
    └── <timestamp>-<seq>-request-<messageID>.json
```

- `<YYYYMMDDHHMMSS>` — folder timestamp (first message of the session).
- `<sessionID>` — opencode session id.
- `<timestamp>` — `Date.now()` of the message.
- `<seq>` — monotonic counter to prevent same-millisecond collisions.
- `<messageID>` — opencode message id.

## What's Captured

Each file contains:

- **Session metadata**: session ID, message ID, agent name, model, variant
- **Message info**: id, role, agent, modelID, providerID, cost, tokens, finish, error
- **Parts**: text content, tool calls (tool name + callID + state), file attachments (mime, filename, url)

## Privacy

The log directory lives under `.ai/telamon/` which is gitignored — no prompts leak into version control.

## opencode v1.14.50 Constraint

The plugin file MUST export ONLY the plugin factory. opencode's plugin loader treats every named export as a plugin factory; an extra named export (e.g. `_resetState`) crashes the hook chain at trigger time with `TypeError: undefined is not an object (evaluating 'H[W]')`. Test helpers are attached as properties on the factory function (e.g. `LlmLoggerPlugin._resetState`) instead of being exported separately.

## Source

[`src/instructions/plugins/llm-logger.js`](https://github.com/hgraca/telamon/blob/main/src/instructions/plugins/llm-logger.js)
