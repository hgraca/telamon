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

### Local LLM dependency

Runs **fully local GGUF models** (auto-downloaded to `storage/qmd/models/`, ~2 GB total):

| Model                 | Purpose                                  |
|-----------------------|------------------------------------------|
| `embeddinggemma`      | Embedding vault documents into vectors   |
| `qwen3-reranker`      | Reranking search results for relevance   |
| `qmd-query-expansion` | Expanding user queries for better recall |

No Docker or Ollama dependency — QMD manages its own model files.
