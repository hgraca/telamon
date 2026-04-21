---
layout: page
title: Configuration
description: Prerequisites, environment variables, and Docker services.
nav_section: docs
---

## Prerequisites

| Requirement | Notes |
|---|---|
| **Linux** (Ubuntu/Debian/Mint) or **macOS** | Apple Silicon and Intel both supported |

`make up` installs **everything** automatically:

| Tool | Install method |
|---|---|
| Docker | System package manager |
| Node.js | Via Homebrew/Linuxbrew |
| Python (uv) | Via Homebrew/Linuxbrew |
| [opencode](https://opencode.ai) | `npm install -g opencode-ai` |
| [Obsidian](https://obsidian.md) | `.deb` (Linux) / `brew install --cask` (macOS) |
| Ogham, Graphify, cass, RTK, QMD, Codebase Index, Caveman | Various (see [Tools](tools.md)) |

> **One manual step:** After Obsidian is installed, the installer pauses and walks you through enabling the *Local REST API* community plugin and copying the API key.

---

## Environment Variables

Copy `.env.dist` to `.env` (done automatically by `make up`) and set:

### Required

```bash
POSTGRES_PASSWORD=your-secure-password
OBSIDIAN_API_KEY=your-obsidian-local-rest-api-key
```

The Obsidian API key comes from: *Obsidian -> Settings -> Community Plugins -> Local REST API -> API Key*.

### Optional — Langfuse

```bash
LANGFUSE_ENABLED=true               # set to "true" to enable the Langfuse stack
LANGFUSE_SECRET=your-random-secret   # NextAuth secret
LANGFUSE_SALT=your-random-salt       # NextAuth salt
```

### Optional — Graphiti

```bash
GRAPHITI_ENABLED=true                # set to "true" to enable Graphiti + Neo4j
NEO4J_PASSWORD=your-neo4j-password
OPENAI_API_KEY=your-openai-key       # used by Graphiti for entity extraction
```

> `OPENAI_API_KEY` is only passed to the Graphiti container — it is not exported globally by Telamon scripts.

---

## Secrets

The installer writes one plain-text file per secret into `storage/secrets/` (git-ignored).
These are referenced by `storage/opencode.jsonc` using the `{file:...}` pattern — the agent never sees raw secrets in config, only file pointers.

| File | Contents | Created by |
|---|---|---|
| `ogham-database-url` | Postgres connection string for Ogham | `make up` |
| `obsidian-api-key` | Obsidian Local REST API key | `make up` |
| `graphify-python` | Absolute path to graphify's Python interpreter | `make up` |
| `telamon-root` | Absolute path to the Telamon root directory | `make up` |
| `gh_pat` | GitHub personal access token | `make up` (prompted) |
| `qmd-cache-home` | XDG_CACHE_HOME override for QMD | `make up` |

---

## Infrastructure Services (Docker)

### Core Services (always running)

| Service | Image | Purpose |
|---|---|---|
| `ogham-postgres` | `pgvector/pgvector:pg17` | Vector database for Ogham memory |
| `telamon-ollama` | `ollama/ollama:latest` | Local embedding model server |
| `telamon-ollama-init` | `ollama/ollama:latest` | One-shot job: pulls `nomic-embed-text` on first start |

> **Obsidian MCP** runs on-demand via `docker run` (not a persistent service) so it does not crash when Obsidian is not running.

### Optional: Langfuse (profile: `langfuse`)

Enabled by setting `LANGFUSE_ENABLED=true` in `.env`. Started automatically by `make up` when the flag is set.

| Service | Image | Purpose |
|---|---|---|
| `telamon-langfuse-db` | `postgres:16` | Langfuse metadata database (port 5433) |
| `telamon-langfuse-redis` | `redis:7-alpine` | Langfuse cache |
| `telamon-langfuse-clickhouse` | `clickhouse/clickhouse-server:latest` | Langfuse analytics store |
| `telamon-langfuse-web` | `langfuse/langfuse:latest` | Langfuse web UI (port 4000) |

### Optional: Graphiti + Neo4j (profile: `graphiti`)

Enabled by setting `GRAPHITI_ENABLED=true` in `.env`. Started automatically by `make up` when the flag is set.

| Service | Image | Purpose |
|---|---|---|
| `telamon-neo4j` | `neo4j:5` | Graph database (browser at port 7474, bolt at port 7687) |
| `telamon-graphiti` | `zepai/graphiti:latest` | Temporal knowledge graph API (port 8001) |

---

## Graphify MCP Server

The Graphify MCP server is registered in `storage/opencode.jsonc` during `make up` and starts on-demand with each opencode session. It requires:

- **`storage/secrets/graphify-python`** — absolute path to the Python interpreter from the `uv tool install graphifyy` venv.
- **`storage/secrets/telamon-root`** — absolute path to the Telamon root directory (injected via `{file:...}` pattern into the MCP environment block).
- **`.opencode/graphify-serve.sh`** — symlink in each project pointing to `src/install/graphify/serve-wrapper.sh`. Created by `make init`.

The wrapper script checks for `graph.json` before starting. If the graph hasn't been built yet, it exits gracefully (no crash).

---

## Scheduled Background Jobs

`make init` creates platform-native timers that run every 30 minutes:

| Job | Command | Scope |
|---|---|---|
| **Graphify update** | `graphify . --update` (falls back to full build) | Per project |
| **Cass index** | `cass index` (incremental session index) | Global (one timer regardless of project count) |

| Platform | Timer mechanism | Location |
|---|---|---|
| Linux | systemd user timer | `~/.config/systemd/user/<job-name>.{service,timer}` |
| macOS | launchd agent | `~/Library/LaunchAgents/com.telamon.<job-name>.plist` |

Job names: `graphify-update-<project>` (per project), `cass-index` (global).

**Managing timers:**

```bash
# Linux — check status
systemctl --user status graphify-update-<project>.timer
systemctl --user status cass-index.timer

# macOS — check status
launchctl list | grep graphify-update
launchctl list | grep cass-index

# Remove timers
bash src/install/graphify/schedule.sh --remove <project-name>
bash src/install/cass/schedule.sh --remove
```

Timers are idempotent — re-running `make init` does not create duplicates. If the timer content is identical, it is skipped.
