# Configuration

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

```bash
POSTGRES_PASSWORD=your-secure-password
OBSIDIAN_API_KEY=your-obsidian-local-rest-api-key
```

The Obsidian API key comes from: *Obsidian -> Settings -> Community Plugins -> Local REST API -> API Key*.

---

## Infrastructure Services (Docker)

| Service | Image | Purpose |
|---|---|---|
| `ogham-postgres` | `pgvector/pgvector:pg17` | Vector database for Ogham memory |
| `telamon-ollama` | `ollama/ollama:latest` | Local embedding model server |
| `telamon-ollama-init` | `ollama/ollama:latest` | One-shot job: pulls `nomic-embed-text` on first start |

> **Obsidian MCP** runs on-demand via `docker run` (not a persistent service) so it does not crash when Obsidian is not running.
