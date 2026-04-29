---
layout: page
title: Configuration
description: Settings, environment variables, and optional service activation.
nav_section: docs
---

## Global settings

The installer handles **everything** automatically. The `.env` file at `~/.telamon/.env` is used only for optional services (see below).

---

## Per-project settings

Each initialized project has a config file at `.ai/telamon/telamon.jsonc` (created by `telamon init`).
Edit this file to override defaults for a specific project.

```jsonc
{
  "project_name": "my-app",
  "medium_model": "",
  "rtk_enabled": false,
  "caveman_enabled": false
}
```

| Key               | Default                          | Description                                                                                                                                                                                              |
|-------------------|----------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `project_name`    | Directory basename               | Display name used in memory vaults and logs                                                                                                                                                              |
| `medium_model`    | *(empty — prompts on first use)* | LLM model for batch operations like `recover-memories`. On first use, the CLI prompts with suggestions from the project's `model`/`small_model` in `opencode.jsonc` (e.g. Opus+Haiku → suggests Sonnet). |
| `rtk_enabled`     | `false` (IO transformation)      | Enable [RTK](tools/rtk) output compression. Set to `true` to run bash commands through RTK rewriting for token savings.                                                                                  |
| `caveman_enabled` | `false` (IO transformation)      | Enable [Caveman](tools/caveman) terse communication mode. Set to `true` for compressed responses that save tokens.                                                                                       |

Both features are **disabled by default** because they perform IO transformations, which carry risks, specially RTK.
Set to `true` in projects where token savings matter (e.g. when using metered API providers).

Changes take effect on the next opencode session — no restart required for RTK (read at plugin init) or Caveman (read at bootstrap).

---

## Optional services

### Langfuse (LLM observability)

```bash
LANGFUSE_ENABLED=true
LANGFUSE_SECRET=your-random-secret
LANGFUSE_SALT=your-random-salt
```

After `telamon up`, open `http://localhost:17400`, create an admin account, and generate API keys.

### Graphiti (temporal knowledge graph)

```bash
GRAPHITI_ENABLED=true
NEO4J_PASSWORD=your-neo4j-password
OPENAI_API_KEY=your-openai-key       # used by Graphiti for entity extraction
```

> `OPENAI_API_KEY` is only passed to the Graphiti container — it is not exported globally.
