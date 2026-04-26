---
layout: page
title: Ogham MCP
description: Semantic agent memory — stores and recalls decisions, bugs, patterns by meaning.
nav_section: docs
---

[ogham-mcp](https://ogham-mcp.dev) — Semantic Agent Memory

Stores and retrieves decisions, bugs, and patterns using semantic vector search.
Backed by a local **Postgres + pgvector** database and **Ollama** embeddings (`nomic-embed-text`).

- Persists knowledge across sessions and projects using named profiles
- Searches by meaning, not exact text
- FlashRank cross-encoder reranking improves result precision (~+8pp MRR)

**MCP tools:** `switch_profile`, `store_memory`, `store_decision`, `store_preference`, `store_fact`, `store_event`, `hybrid_search`, `explore_knowledge`, `list_recent`, `find_related`, `suggest_connections`, `compress_old_memories`

**Priority:** Tier 1 — highest ROI, essential.
