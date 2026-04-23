---
layout: page
title: Configuration
description: Prerequisites, environment variables, and Docker services.
nav_section: docs
---

## Essentials

| Requirement | Notes |
|---|---|
| **Linux** (Ubuntu/Debian/Mint) or **macOS** | Apple Silicon and Intel both supported |

The installer handles **everything** automatically. After install, set two values in `~/.telamon/.env`:

```bash
POSTGRES_PASSWORD=your-secure-password    # set during install
OBSIDIAN_API_KEY=your-obsidian-api-key    # from Obsidian → Settings → Community Plugins → Local REST API
```

That's it for basic usage.

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

---

## Per-project settings

Each initialized project has a config file at `.ai/telamon/telamon.ini` (created by `telamon init`). Edit this file to override defaults for a specific project.

```ini
[telamon]
project_name = my-app
rtk_enabled = false
caveman_enabled = false
```

| Key | Default | Description |
|---|---|---|
| `project_name` | Directory basename | Display name used in memory vaults and logs |
| `rtk_enabled` | `false` | Enable [RTK](tools.md#rtk--token-compression-proxy) output compression. Set to `true` to run bash commands through RTK rewriting for token savings. |
| `caveman_enabled` | `false` | Enable [Caveman](tools.md#caveman--token-efficient-communication-mode) terse communication mode. Set to `true` for compressed responses that save tokens. |

Both features are **disabled by default**. Set to `true` in projects where token savings matter (e.g. when using metered API providers).

Changes take effect on the next opencode session — no restart required for RTK (read at plugin init) or Caveman (read at bootstrap).

---

## Under the hood

### What the installer installs

`make up` installs everything automatically:

| Tool | Install method |
|---|---|
| Docker | System package manager |
| Node.js | Via Homebrew/Linuxbrew |
| Python (uv) | Via Homebrew/Linuxbrew |
| [opencode](https://opencode.ai) | `npm install -g opencode-ai` |
| [Obsidian](https://obsidian.md) | `.deb` (Linux) / `brew install --cask` (macOS) |
| `telamon` CLI | Symlink at `~/.local/bin/telamon` + desktop menu entry |
| Ogham, Graphify, RTK, QMD, Codebase Index, Caveman | Various (see [Tools](tools.md)) |

> **One manual step:** After Obsidian is installed, the installer pauses and walks you through enabling the *Local REST API* community plugin and copying the API key.

### Secrets

The installer writes one plain-text file per secret into `storage/secrets/` (git-ignored).
These are referenced by `storage/opencode.jsonc` using the `{file:...}` pattern — the agent never sees raw secrets in config, only file pointers.

| File | Contents |
|---|---|
| `ogham-database-url` | Postgres connection string for Ogham |
| `obsidian-api-key` | Obsidian Local REST API key |
| `graphify-python` | Path to graphify's Python interpreter |
| `telamon-root` | Path to the Telamon root directory |
| `gh_pat` | GitHub personal access token |
| `qmd-cache-home` | XDG_CACHE_HOME override for QMD |

### Docker services

#### Core (always running)

| Service | Image | Host port |
|---|---|---|
| `ogham-postgres` | `pgvector/pgvector:pg17` | 17432 |
| `telamon-ollama` | `ollama/ollama:latest` | 17434 |
| `telamon-ollama-init` | `ollama/ollama:latest` | — (one-shot, pulls `nomic-embed-text`) |

> **Obsidian MCP** runs on-demand via `docker run` (not persistent) so it doesn't crash when Obsidian isn't running.

#### Langfuse (profile: `langfuse`)

| Service | Image | Host port |
|---|---|---|
| `telamon-langfuse-db` | `postgres:16` | 17433 |
| `telamon-langfuse-redis` | `redis:7-alpine` | — (internal only) |
| `telamon-langfuse-clickhouse` | `clickhouse/clickhouse-server` | — (internal only) |
| `telamon-langfuse-web` | `langfuse/langfuse:latest` | 17400 |

#### Graphiti + Neo4j (profile: `graphiti`)

| Service | Image | Host port |
|---|---|---|
| `telamon-neo4j` | `neo4j:5` | 17474 (browser), 17687 (bolt) |
| `telamon-graphiti` | `zepai/graphiti:latest` | 17801 |

> All host ports are bound to `127.0.0.1` — not accessible from the network.

### Scheduled background jobs

`telamon init` creates platform-native timers that run every 30 minutes:

| Job | Command | Scope |
|---|---|---|
| **Graphify update** | `graphify . --update` | Per project |

| Platform | Mechanism | Location |
|---|---|---|
| Linux | systemd user timer | `~/.config/systemd/user/<job-name>.{service,timer}` |
| macOS | launchd agent | `~/Library/LaunchAgents/com.telamon.<job-name>.plist` |

Timers are idempotent — re-running `telamon init` does not create duplicates.

### Graphify MCP server

Registered during install and starts on-demand with each opencode session. Requires:

- `storage/secrets/graphify-python` — path to graphify's Python interpreter
- `storage/secrets/telamon-root` — path to the Telamon root directory
- `.opencode/graphify-serve.sh` — symlink in each project (created by `telamon init`)

The wrapper checks for `graph.json` before starting. If the graph hasn't been built yet, it exits gracefully.
