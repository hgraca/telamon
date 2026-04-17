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
