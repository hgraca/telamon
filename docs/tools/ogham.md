---
layout: page
title: Ogham (Retired)
description: Semantic memory store backed by pgvector — retired due to complexity and fragility.
nav_section: docs
---

# Ogham (Retired)

[Ogham](https://github.com/toowired/ogham) — a semantic memory store backed by PostgreSQL + pgvector. Agents stored and retrieved episodic memories (session checkpoints, decisions, patterns) via CLI commands.

**What it provided:**

- `ogham store` — persist structured memories with embeddings
- `ogham search` — semantic retrieval over past sessions and decisions
- `ogham hooks recall/inscribe` — context restoration after compaction
- Profile-based project isolation (`ogham use <project>`)

**Why it was retired:**

- **Complexity** — Required a running PostgreSQL instance with pgvector extension, Docker compose orchestration, and profile management. The `make up` sequence had ordering issues (Ogham install needed Postgres to be running).
- **Fragility** — The database occasionally vanished (Docker volume issues, reinstalls), requiring LLM tokens to rebuild the entire memory store from scratch.
- **Comparable alternative** — QMD provides similar semantic search capabilities with a much simpler setup: fully local, file-based, no database dependency, no Docker requirement.

**Replacement:** [QMD](qmd) — semantic search over the knowledge vault with zero infrastructure overhead.
