---
layout: page
title: Codebase Index
description: Semantic code search — find code by natural language description.
nav_section: docs
---

[Codebase Index](https://github.com/Helweg/opencode-codebase-index) — Semantic Code Search

Indexes the project's source code using Ollama embeddings, enabling natural-language search.

- Ask naturally: *"find the authentication logic"*, *"where is the payment handler?"*
- Results ranked by semantic similarity
- Built once per project; a file watcher maintains it automatically

Complements Graphify: Graphify tells you the structure, Codebase Index lets you find code by meaning.

**MCP tools:** `codebase_search`, `codebase_peek`, `implementation_lookup`, `call_graph`, `find_similar`, `index_codebase`, `index_status`, `index_health_check`

### Local LLM dependency

Uses **Ollama** running `nomic-embed-text` for generating embeddings.

- Docker container: `telamon-ollama` (port `17434`)
- Init container: `telamon-ollama-init` pulls the model on first start
- No cloud API calls — all embedding computation is local
