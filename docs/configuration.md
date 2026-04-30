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
  "rtk_enabled": true,
  "caveman_enabled": true
}
```

| Key               | Default                          | Description                                                                                                                                                                                              |
|-------------------|----------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `project_name`    | Directory basename               | Display name used in memory vaults and logs                                                                                                                                                              |
| `medium_model`    | *(empty — prompts on first use)* | LLM model for batch operations like `recover-memories`. On first use, the CLI prompts with suggestions from the project's `model`/`small_model` in `opencode.jsonc` (e.g. Opus+Haiku → suggests Sonnet). |
| `rtk_enabled`     | `true`                           | Enable [RTK](tools/rtk) output compression. Runs bash commands through RTK rewriting for token savings. Set to `false` to disable.                                                                       |
| `caveman_enabled` | `true`                           | Enable [Caveman](tools/caveman) terse communication mode. Compressed responses that save tokens. Set to `false` to disable.                                                                              |

Both features are **enabled by default** because they significantly reduce token usage.
Set to `false` in projects where you prefer verbose output or if RTK causes issues with specific command output.

Changes take effect on the next opencode session — no restart required for RTK (read at plugin init) or Caveman (read at bootstrap).

---

## Global settings (`.telamon.jsonc`)

The file `.telamon.jsonc` in the Telamon root directory contains global settings that apply to the Telamon installation itself (not per-project).

```jsonc
{
  "modules": { ... },
  "opencode_patches": []
}
```

| Key                | Default | Description                                                                                                                     |
|--------------------|---------|---------------------------------------------------------------------------------------------------------------------------------|
| `modules`          | `{}`    | External modules (agent skills, commands, plugins) from git repos                                                               |
| `opencode_patches` | `[]`    | Array of GitHub PR URLs to apply when building opencode from source. See [Opencode Patches](tools/opencode-patches) for details |

When `opencode_patches` is non-empty, opencode is built from source with the specified patches applied on every `make update` or `make install`.

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
