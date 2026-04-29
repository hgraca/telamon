---
layout: page
title: Cass (Retired)
description: Conversation history search — retired due to indexing performance issues.
nav_section: docs
---

Cass — Conversation History Search (Retired)

[cass](https://github.com/toowired/cass)

Cass indexed past agent session transcripts and provided full-text search over them, enabling agents to recall context from previous conversations — *"did we discuss X last week?"*

**What we tried:**

- **Git hook indexing** — Running `cass index` as a post-commit or pre-push hook. Indexing was too slow; hooks that block for minutes are unusable.
- **Scheduled indexing (every 30 minutes)** — A background timer ran `cass index` on a recurring schedule. The indexing process was resource-intensive enough to bog down the machine.

**Why it was retired:**

The core problem was indexing cost. Session transcripts grow quickly, and Cass's indexing was neither fast enough for 
synchronous triggers nor lightweight enough for frequent background runs. On a typical development machine already 
running Postgres, Ollama, Docker, and an LLM-backed agent, adding another heavy periodic process caused noticeable slowdowns.

**Replacement:** The `recover-memories` functionality in the recall-memories skill now serves the session history search use case, using semantic search over memories promoted by session-capture.
