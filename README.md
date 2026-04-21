# Telamon

A harness for agentic software development.

Everything a developer needs to get the best out of LLMs and coding agents —
installed once, shared across every project and tailored for every project.

All tools run locally. No data leaves your machine.

---

## Features

Telamon is a **local infrastructure kit** that installs, wires up, and manages a suite of AI-augmentation
tools for software development. It provides:

- **Persistent agent memory** — the agent remembers decisions, bugs, and patterns across sessions and projects
- **Codebase understanding** — semantic code search and a structural knowledge graph
- **Curated knowledge vault** — human-readable notes that survive model resets
- **Session recall** — searchable history of every past agent conversation
- **Automatic session capture** — learnings are promoted to memory before context is compacted
- **Token efficiency** — automatic compression of context sent to the LLM
- **Multi-agent system** — 10 specialized agent roles (architect, developer, tester, reviewer, and more) with structured delegation
- **Slash commands** — `/plan`, `/implement`, `/story`, `/epic`, `/review`, `/test`, and more
- **Rich MCP integrations** — GitHub, browser DevTools, Playwright, AST search, library docs, web search
- **Optional observability** — Langfuse for token tracking and prompt debugging (opt-in)
- **Optional temporal knowledge graph** — Graphiti + Neo4j for tracking architectural evolution (opt-in)

---

## Quick Start

| Requirement | Notes |
|---|---|
| **Linux** (Ubuntu/Debian/Mint) or **macOS** | Apple Silicon and Intel both supported |

> `make up` installs **everything** — Docker, Node.js, Python, [opencode](https://opencode.ai), Obsidian, Ogham, Graphify, cass, RTK, QMD, Codebase Index, Caveman, and the global `telamon` CLI.
> The only manual step: after Obsidian is installed, the installer pauses and walks you through enabling the *Local REST API* plugin.

```bash
# 1. Clone and install (one-time)
git clone <this-repo> ~/telamon
cd ~/telamon
make up

# 2. Initialise a project (one-time per project — from anywhere)
telamon init path/to/your-project
# or: cd path/to/your-project && telamon init

# 3. Start working — open the project in opencode
cd path/to/your-project
opencode
```

After `make up`, the `telamon` command is available globally — see [Commands](docs/make-targets.md) for the full list.

See [Developer Workflow](docs/developer-workflow.md) for the full day-to-day guide.

---

## Documentation

| Document | Contents |
|---|---|
| [Tools](docs/tools.md) | Detailed description of every tool — what it does, how it works, priority guide |
| [Developer Workflow](docs/developer-workflow.md) | Day-to-day usage: install, init, session lifecycle, saving knowledge, wrap-up |
| [System Architecture](docs/system-architecture.md) | System flow diagram and what each tool provides at each stage |
| [Configuration](docs/configuration.md) | Prerequisites, environment variables, Docker services |
| [Commands](docs/make-targets.md) | `telamon` CLI commands and `make` targets |
| [Repository Layout](docs/repository-layout.md) | Full directory structure explained |

## Tools

### Persistent Agent Memory

The agent remembers decisions, bugs, and patterns across sessions and projects.

| Tool | Role |
|---|---|
| [Ogham MCP](https://github.com/ogham-mcp/ogham-mcp) | Semantic vector store — stores and retrieves knowledge by meaning |
| [Postgres + pgvector](https://github.com/pgvector/pgvector) | Vector database backing Ogham |
| [Ollama](https://ollama.ai) | Local embedding model server (`nomic-embed-text`) |

### Codebase Understanding

The agent knows the structure of the codebase and can find code by meaning.

| Tool | Role |
|---|---|
| [Graphify](https://github.com/safishamsi/graphify) | Structural knowledge graph — auto-built, updated every 30 min, MCP server + context injection |
| [Codebase Index](https://github.com/Helweg/opencode-codebase-index) | Semantic code search — find code by natural language description |

### Curated Knowledge Vault

Human-readable, long-lived notes that survive model resets — goals, decisions, patterns, gotchas.

| Tool | Role |
|---|---|
| [Obsidian MCP](https://github.com/oleksandrkucherenko/obsidian-mcp) | Read/write bridge to an Obsidian vault per project |
| [QMD](https://github.com/tobi/qmd) | Semantic search over the vault using local GGUF models |

### Session Recall

The agent recovers context from previous conversations.

| Tool | Role |
|---|---|
| [Cass](https://github.com/dicklesworthstone/coding_agent_session_search) | Full-text search over past agent session transcripts |

### Automatic Session Capture

Learnings are promoted to memory before context is compacted — no manual intervention.

| Tool | Role |
|---|---|
| Session Capture plugin | Fires after each agent turn (throttled) and on explicit *"wrap up"* |

### Token Efficiency

Reduces token consumption and cost automatically.

| Tool | Role |
|---|---|
| [RTK](https://github.com/rtk-ai/rtk) | Compresses bash command output before it reaches the LLM |
| [Caveman](https://github.com/JuliusBrussee/caveman) | Ultra-compressed communication mode (~75% reduction on demand) |

### Multi-Agent Workflow

Structured skills for planning, implementing, reviewing, and shipping software.

| Tool | Role |
|---|---|
| [Telamon workflow skills](docs/tools.md#specialized-agent-skills) | Plan stories, implement with tester->developer->reviewer cycles, review changesets, audit codebases |
| [Addy Osmani skills](https://github.com/addyosmani/agent-skills) | General engineering skills — TDD, debugging, API design, security, CI/CD, and more |
| [Multi-agent roles](docs/tools.md#multi-agent-roles) | 10 specialized agents: orchestrator, architect, developer, tester, reviewer, critic, PO, security, UI designer, UX designer |
| [Slash commands](docs/tools.md#slash-commands) | `/plan`, `/implement`, `/story`, `/epic`, `/review`, `/test`, `/dev`, `/gh_review`, `/archive`, `/caveman`, `/vault-audit` |

### Optional: Observability & Advanced Knowledge

| Tool | Role |
|---|---|
| [Langfuse](https://langfuse.com) | Self-hosted LLM observability — token usage, latency, cost tracking (opt-in via `LANGFUSE_ENABLED=true`) |
| [Graphiti](https://github.com/getzep/graphiti) + [Neo4j](https://neo4j.com) | Temporal knowledge graph — tracks how entities and relationships evolve (opt-in via `GRAPHITI_ENABLED=true`) |

### MCP Integrations

External tools exposed to every project via MCP servers.

| Tool | Role |
|---|---|
| [GitHub MCP](https://github.com/modelcontextprotocol/servers) | Issues, PRs, code search, reviews |
| [Chrome DevTools MCP](https://github.com/nichochar/chrome-devtools-mcp) | Browser inspection and debugging |
| [Playwright](https://github.com/modelcontextprotocol/servers) | Browser automation and testing |
| [ast-grep](https://github.com/modelcontextprotocol/servers) | Structural code search using AST patterns |
| [Context7](https://context7.com) | Up-to-date library and framework documentation |
| [Exa](https://exa.ai) | Web search |
| [grep.app](https://grep.app) | Code search across public GitHub repositories |

---

## Acknowledgements

- [Ogham MCP](https://ogham-mcp.dev)
- [Graphify](https://github.com/safishamsi/graphify)
- [Codebase Index](https://github.com/Helweg/opencode-codebase-index)
- [Obsidian MCP](https://github.com/oleksandrkucherenko/obsidian-mcp) & [Obsidian Mind](https://github.com/breferrari/obsidian-mind)
- [QMD](https://github.com/tobi/qmd)
- [Cass](https://github.com/dicklesworthstone/coding_agent_session_search)
- [RTK](https://github.com/rtk-ai/rtk)
- [Caveman](https://github.com/JuliusBrussee/caveman)
- [Addy Osmani Skills](https://github.com/addyosmani/agent-skills)
- [PentAGI](https://github.com/vxcontrol/pentagi)
- [Langfuse](https://langfuse.com)
- [Graphiti](https://github.com/getzep/graphiti)
- [Context7](https://context7.com)
- [Exa](https://exa.ai)
- [grep.app](https://grep.app)
