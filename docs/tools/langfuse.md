---
layout: page
title: Langfuse
description: Self-hosted LLM observability — token usage, latency, cost tracking.
nav_section: docs
---

[Langfuse](https://langfuse.com) — Observability (Optional)

Self-hosted LLM observability platform. Tracks token usage, latency, cost, and prompt/response pairs.
Enable by setting `LANGFUSE_ENABLED=true` in `.env`.

- Runs as a Docker Compose profile with Postgres, Redis, ClickHouse, and the web app
- Accessible at `http://localhost:17400` after startup

**Status:** Optional — enable when needed.
