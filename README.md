# Telamon

A harness for agentic software development.

Everything a developer needs to get the best out of LLMs and coding agents —
installed once, shared across every project and tailored for every project.

All tools run locally. No data leaves your machine.

---

## Quick Start

| Requirement | Notes |
|---|---|
| **Linux** (Ubuntu/Debian/Mint) or **macOS** | Apple Silicon and Intel both supported |

```bash
# 1. Install (one-time)
curl -fsSL https://raw.githubusercontent.com/hgraca/telamon/main/install.sh | bash

# 2. Initialise a project (one-time per project)
telamon init path/to/your-project

# 3. Start working
cd path/to/your-project && opencode
```

> The installer sets up **everything** — Docker, Node.js, Python, [opencode](https://opencode.ai), Obsidian, Ogham, Graphify, RTK, QMD, Codebase Index, Caveman, and the global `telamon` CLI.
> The only manual step: after Obsidian is installed, the installer pauses and walks you through enabling the *Local REST API* plugin.

---

## What it does

| Capability | How |
|---|---|
| **Persistent agent memory** | Ogham MCP + Postgres + pgvector + Ollama |
| **Codebase understanding** | Graphify (knowledge graph) + Codebase Index (semantic search) |
| **Curated knowledge vault** | Obsidian MCP + QMD (semantic vault search) |
| **Session recall** | Cass (conversation history search) |
| **Automatic session capture** | OpenCode plugin — promotes learnings before compaction |
| **Token efficiency** | RTK (output compression) + Caveman (terse communication mode) |
| **Multi-agent system** | 2 agents: Telamon (autonomous orchestrator + 10 sub-agents) and Companion (pair programmer) |
| **MCP integrations** | GitHub, Chrome DevTools, Playwright, ast-grep, Context7, Exa, grep.app |
| **Optional observability** | Langfuse for token tracking (opt-in) |
| **Optional temporal graph** | Graphiti + Neo4j for architectural evolution (opt-in) |

---

## Documentation

| Document | Contents |
|---|---|
| [Developer Workflow](docs/developer-workflow.md) | Day-to-day usage: install, init, session lifecycle, wrap-up |
| [Tools](docs/tools.md) | Every tool — what it does, how it works, priority guide |
| [Configuration](docs/configuration.md) | Environment variables, Docker services, secrets, background jobs |
| [System Architecture](docs/system-architecture.md) | System flow diagram, what each tool provides at each stage |
| [Commands](docs/make-targets.md) | `telamon` CLI commands and `make` targets |
| [Repository Layout](docs/repository-layout.md) | Full directory structure explained |

---

## Contributors

<!-- CONTRIBUTORS-START -->
<!-- CONTRIBUTORS-END -->

---

## Acknowledgements

- [Ogham MCP](https://ogham-mcp.dev)
- [Graphify](https://github.com/safishamsi/graphify)
- [Codebase Index](https://github.com/Helweg/opencode-codebase-index)
- [Obsidian MCP](https://github.com/oleksandrkucherenko/obsidian-mcp)
- [QMD](https://github.com/tobi/qmd)
- [RTK](https://github.com/rtk-ai/rtk)
- [Caveman](https://github.com/JuliusBrussee/caveman)
- [Addy Osmani Skills](https://github.com/addyosmani/agent-skills)
- [PentAGI](https://github.com/vxcontrol/pentagi)
- [Langfuse](https://langfuse.com)
- [Graphiti](https://github.com/getzep/graphiti)
- [Context7](https://context7.com)
- [Exa](https://exa.ai)
- [grep.app](https://grep.app)
