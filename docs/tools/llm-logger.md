---
layout: page
title: LLM Logger
description: Logs every LLM user request and assistant response to disk for debugging and analysis.
nav_section: docs
---

# LLM Logger Plugin

Logs every user message and assistant response to disk — one file per message.

## How It Works

The plugin uses two hooks:

- **`chat.message`** — fires once per user message with the full message body and parts (text, file attachments, agent invocations). Captures the user side of every LLM exchange.
- **`event`** (filtered) — listens for `message.updated` events with `info.role === "assistant"` and `info.time.completed` set, then fetches the full message + parts via `client.session.message(...)` and writes one log file per assistant message. Repeated `message.updated` events for the same `messageID` are deduplicated via an in-memory `Set`.

System prompts are NOT captured by this plugin. The `experimental.chat.system.transform` hook crashes startup in opencode v1.14.50.

## File Layout

```
.ai/telamon/logs/llm-logger/
└── <YYYYMMDDHHMMSS>-<sessionID>/
    ├── <timestamp>-<seq>-request-<messageID>.json   ← user message
    └── <timestamp>-<seq>-response-<messageID>.json  ← assistant message
```

- `<YYYYMMDDHHMMSS>` — folder timestamp (first message of the session).
- `<sessionID>` — opencode session id.
- `<timestamp>` — `Date.now()` of the message.
- `<seq>` — monotonic counter to prevent same-millisecond collisions.
- `<messageID>` — opencode message id.

## What's Captured

Each file contains:

- **Session metadata**: session ID, message ID, agent name, model, variant
- **Message info**: id, role, agent, modelID, providerID, cost, tokens, finish, error, time (created/completed)
- **Parts**: text content, tool calls (tool name + callID + state), file attachments (mime, filename, url)

For assistant messages, if the `client.session.message(...)` fetch fails, the plugin falls back to writing a metadata-only log (no parts) so the event is never silently dropped.

## Privacy

The log directory lives under `.ai/telamon/` which is gitignored — no prompts leak into version control.

## opencode v1.14.50 Constraint

The plugin file MUST export ONLY the plugin factory. opencode's plugin loader treats every named export as a plugin factory; an extra named export (e.g. `_resetState`) crashes the hook chain at trigger time with `TypeError: undefined is not an object (evaluating 'H[W]')`. Test helpers are attached as properties on the factory function (e.g. `LlmLoggerPlugin._resetState`) instead of being exported separately.

## Source

[`src/instructions/plugins/llm-logger.js`](https://github.com/hgraca/telamon/blob/main/src/instructions/plugins/llm-logger.js)
