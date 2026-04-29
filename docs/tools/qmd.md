---
layout: page
title: QMD
description: Semantic search over the knowledge vault using local GGUF models.
nav_section: docs
---

[QMD](https://github.com/tobi/qmd) — Vault Semantic Search

Semantic search over the knowledge vault using **fully local GGUF models** (~2 GB, auto-downloaded).

- One named collection per vault section: `<project>-brain`, `-work`, `-reference`, `-thinking`
- MCP server with `query`, `get`, `multi_get`, and `status` tools
- `qmd update && qmd embed` keeps the index current (fast incremental refresh)

**Priority:** Tier 3
