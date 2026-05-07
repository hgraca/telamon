# Telamon

A harness for agentic software development.

Everything a developer needs to get the best out of LLMs and coding agents —
installed once, shared across every project and tailored for every project.

All tools run locally. No data leaves your machine.

---

## Quick Start

| Requirement                                 | Notes                                  |
|---------------------------------------------|----------------------------------------|
| **Linux** (Ubuntu/Debian/Mint) or **macOS** | Apple Silicon and Intel both supported |

```bash
# 1. Install (one-time)
curl -fsSL https://raw.githubusercontent.com/hgraca/telamon/main/install.sh | bash

# 2. Initialise a project (one-time per project)
telamon init path/to/your-project

# 3. Start working
cd path/to/your-project && opencode
```

> The installer sets up **everything** — Docker, Node.js, Python, [opencode](https://opencode.ai), Graphify, RTK, QMD, Codebase Index, Caveman, and the global `telamon` CLI.

---

## What it does

| Capability                    | How                                                                                         |
|-------------------------------|---------------------------------------------------------------------------------------------|
| **Multi-agent system**        | 2 agents: Telamon (autonomous orchestrator + 10 sub-agents) and Companion (pair programmer) |
| **Persistent agent memory**   | Ollama + markdown vault                                                                     |
| **Curated knowledge vault**   | QMD (semantic vault search) + direct file read/write                                        |
| **Automatic session capture** | OpenCode plugin — promotes learnings before compaction                                      |
| **Codebase understanding**    | Graphify (knowledge graph) + Codebase Index (semantic search)                               |
| **Token efficiency**          | RTK (output compression) + Caveman (terse communication mode)                               |
| **MCP integrations**          | GitHub, Chrome DevTools, Playwright, ast-grep, Context7, Exa, grep.app                      |
| **Optional observability**    | Langfuse for token tracking (opt-in)                                                        |
| **Optional temporal graph**   | Graphiti + Neo4j for architectural evolution (opt-in)                                       |

---

## Documentation

- [Developer Workflow](docs/developer-workflow.md) — Day-to-day usage: install, init, session lifecycle, wrap-up
- [Tools](docs/tools/) — Every tool, how it works, priority guide
  - [Session Capture](docs/tools/remember-session.md), [Status Marker Enforcer](docs/tools/status-marker-enforcer.md), [Diff Context](docs/tools/diff-context.md), [Active Work Context](docs/tools/active-work-context.md), [Compaction Save](docs/tools/compaction-save.md) — Memory & session
  - [Graphify](docs/tools/graphify.md), [Codebase Index](docs/tools/codebase-index.md), [Repomix](docs/tools/repomix.md) — Codebase understanding
  - [QMD](docs/tools/qmd.md) — Knowledge vault
  - [RTK](docs/tools/rtk.md), [Caveman](docs/tools/caveman.md), [promptfoo](docs/tools/promptfoo.md) — Token efficiency & quality
  - [Langfuse](docs/tools/langfuse.md), [Graphiti](docs/tools/graphiti.md) — Optional services
  - [Plugins](docs/tools/plugins.md) — OpenCode plugins
  - [Retired experiments](docs/tools/cass.md) — [Cass](docs/tools/cass.md), [Discord](docs/tools/discord.md), [Ogham](docs/tools/ogham.md), [Obsidian](docs/tools/obsidian.md)
- [Agents](docs/agents.md) — Primary agents, sub-agents, and roles
- [Commands](docs/commands.md) — Slash commands available in opencode
- [Skills](docs/skills.md) — Structured instruction sets for agents
- [Configuration](docs/configuration.md) — Environment variables and optional service activation
- [CLI](docs/cli.md) — `telamon` CLI commands and `make` targets
- [Architecture](docs/architecture.md) — System flow, infrastructure, and repository layout

---

## Contributors

<!-- CONTRIBUTORS-START -->
<!-- CONTRIBUTORS-END -->

---

## Acknowledgements

- [Graphify](https://github.com/safishamsi/graphify)
- [Codebase Index](https://github.com/Helweg/opencode-codebase-index)
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
