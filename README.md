# Agentic Development Kit (ADK)

> Everything a developer needs to get the best out of LLMs and coding agents — installed once, shared across every project.

---

## Overview

The ADK is a **local infrastructure kit** that installs, wires up, and manages a suite of AI-augmentation 
tools for software development. It provides:

- **Persistent agent memory** — the agent remembers decisions, bugs, and patterns across sessions and projects
- **Codebase understanding** — semantic code search and a structural knowledge graph
- **Curated knowledge vault** — human-readable notes that survive model resets
- **Session recall** — searchable history of every past agent conversation
- **Token efficiency** — automatic compression of context sent to the LLM

All tools run locally. No data leaves your machine.

---

## Tools

### 🧠 Ogham MCP — Semantic Agent Memory
[ogham-mcp](https://github.com/ogham-mcp/ogham-mcp)

Stores and retrieves decisions, bugs, and patterns using semantic vector search. 
Backed by a local **Postgres + pgvector** database and **Ollama** embeddings (`nomic-embed-text`). 
Exposed to the agent via an MCP server.

- Persists knowledge across sessions and projects using named profiles
- Searches by meaning, not exact text
- FlashRank cross-encoder reranking improves result precision (~+8pp MRR)

**Agent commands:** `ogham use <profile>`, `ogham store "..."`, `ogham search "..."`, `ogham hooks recall`, `ogham hooks inscribe`

---

### 🗺️ Graphify — Codebase Knowledge Graph
[graphify](https://github.com/graphifyy/graphifyy)

Builds a structural knowledge graph of the codebase. Identifies god nodes, architectural layers, c
all relationships, and module boundaries. 
Maintained automatically via git hooks after the initial build.

- Built once with `graphify .`; git hooks keep it current after every commit
- `graphify-out/GRAPH_REPORT.md` is the entry point for architectural context
- Query with `graphify query "<question>"`

---

### 🔍 Codebase Index — Semantic Code Search
[opencode-codebase-index-mcp](https://www.npmjs.com/package/opencode-codebase-index-mcp)

Indexes the project's source code using Ollama embeddings, enabling natural-language semantic search over the codebase. 
Built once per project; a file watcher maintains it automatically.

- Ask naturally: *"find the authentication logic"*, *"where is the payment handler?"*
- Results ranked by semantic similarity
- Exposed as an MCP tool (`index_codebase` / `search_codebase`)

---

### 📚 Obsidian MCP — Curated Knowledge Vault
[obsidian-mcp](https://github.com/oleksandrkucherenko/obsidian-mcp)

Bridges the agent to an **Obsidian** vault containing long-lived, human-curated knowledge: 
project goals, architectural decisions, codebase patterns, and known gotchas. 
Each project gets a `brain/` folder that is **always read at session start**.

```
<project>/brain/
  NorthStar.md     ← goals, focus areas, off-limits — READ FIRST
  KeyDecisions.md  ← architectural decisions with rationale
  Patterns.md      ← established codebase conventions
  Gotchas.md       ← traps, constraints, known issues
```

Obsidian must be installed separately (see [Prerequisites](#prerequisites)).

---

### 🗂️ cass — Agent Session History Search
[cass](https://github.com/dicklesworthstone/cass)

Indexes past agent session conversations and makes them full-text searchable. 
Useful for recovering context from previous sessions: *"what did we decide about the payment flow last week?"*

- Built once with `cass index`; updates automatically
- Search with `cass search "<topic>"`

---

### ⚡ RTK — Token Compression Proxy
[rtk](https://github.com/rtk-ai/rtk)

Transparently compresses bash command output before it reaches the LLM, reducing token consumption and cost. 
Installed as an opencode plugin that auto-patches shell commands.

- Installed globally and wired into opencode automatically (`rtk init -g --opencode --auto-patch`)
- No configuration needed; works transparently

---

### 🐋 Infrastructure Services (Docker)

| Service | Image | Purpose |
|---|---|---|
| `ogham-postgres` | `pgvector/pgvector:pg17` | Vector database for Ogham memory |
| `adk-ollama` | `ollama/ollama:latest` | Local embedding model server |
| `adk-ollama-init` | `ollama/ollama:latest` | One-shot job: pulls `nomic-embed-text` on first start |
| `obsidian-mcp` | `oleksandrkucherenko/obsidian-mcp:latest` | Bridges agent to Obsidian vault |

---

## System Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        Developer Machine                        │
│                                                                 │
│  ┌──────────┐    ┌─────────────────────────────────────────┐    │
│  │ opencode │◄──►│              MCP Layer                  │    │
│  │  (agent) │    │  ┌──────────┐ ┌───────────┐ ┌─────────┐ │    │
│  └──────────┘    │  │  ogham   │ │ codebase- │ │obsidian │ │    │
│       │          │  │   MCP    │ │   index   │ │   MCP   │ │    │
│       │          │  └────┬─────┘ └─────┬─────┘ └────┬────┘ │    │
│       │          └───────┼─────────────┼────────────┼──────┘    │
│       │                  │             │            │           │
│       │          ┌───────▼──────┐  ┌───▼───┐  ┌─────▼─────┐     │
│       │          │  Postgres +  │  │Ollama │  │ Obsidian  │     │
│       │          │  pgvector    │  │:11434 │  │   vault   │     │
│       │          └──────────────┘  └───────┘  └───────────┘     │
│       │                                                         │
│  ┌────▼──────────────────────────────────────────────────────┐  │
│  │                   Host CLI Tools                          │  │
│  │  graphify  ·  cass  ·  rtk  ·  ogham                      │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### What each tool provides at each stage

| Stage | Tool | Role |
|---|---|---|
| **Session start** | Ogham | Recalls past decisions, bugs, and patterns for this project |
| **Session start** | Obsidian `brain/` | Loads goals, decisions, patterns, and known gotchas |
| **Understanding code** | Graphify | Structural map: layers, god nodes, module relationships |
| **Finding code** | Codebase Index | Semantic search: *"where is the auth logic?"* |
| **Recovering past context** | cass | Searches previous agent session transcripts |
| **Writing code** | RTK | Compresses bash output to save tokens |
| **After significant work** | Ogham | Stores new decisions, patterns, bug fixes |
| **After significant work** | Obsidian | Promotes learnings to `brain/` notes |
| **End of session** | Ogham + Obsidian | Inscribes session summary; archives completed work notes |

---

## Developer Workflow

### 1. One-time: Clone and start the ADK

```bash
git clone <this-repo> ~/adk
cd ~/adk
make up
```

`make up` will:
1. Copy `.env.dist` → `.env` (if not present) — edit it to set your Postgres password and Obsidian API key
2. Run `src/install/run.sh` — installs all host tools (Homebrew, Docker, Python/uv, Node.js, Ogham, Graphify, cass, RTK) and writes opencode config files
3. Start Docker services (`postgres`, `ollama`, `obsidian-mcp`)

> The installer is **idempotent** — safe to re-run at any time. Already-installed tools are skipped.

---

### 2. One-time per project: Initialise

```bash
make init PROJ=path/to/your-project
```

This will:
- Create `storage/<project-name>/brain/` with scaffold notes (`NorthStar.md`, `KeyDecisions.md`, `Patterns.md`, `Gotchas.md`)
- Symlink `<project>/.ai/context/adk` → `<adk-root>/src/context` (agent instruction docs)
- Symlink `<project>/.opencode/skills/adk` → `<adk-root>/src/skills` (agent skills)
- Write `<project>/.ai/adk.ini` with the project name variable

After this, when `opencode` starts in the project, it automatically loads the ADK context and skills.

---

### 3. Every day: Start the ADK

```bash
cd ~/adk
make up       # if not already running
```

Check status at any time:

```bash
make status
```

---

### 4. Every agent session: Memory bootstrap

At the start of every session the agent (via the `memory-stack` skill) will:

```bash
ogham use <project-name>     # activate this project's memory profile
ogham hooks recall            # surface relevant past context
```

Then check and build (once each, if missing):
- Graphify knowledge graph: `graphify .`
- Codebase index: `index_codebase` tool
- cass index: `cass index`

---

### 5. During work

The agent automatically:
- Searches Ogham before repeating known work: `ogham search "<topic>"`
- Searches the codebase semantically via the codebase-index MCP
- Queries Graphify for architectural context: `graphify query "<question>"`
- Searches past sessions when needed: `cass search "<topic>"`
- Reads `brain/NorthStar.md` to stay aligned with goals

---

### 6. Saving knowledge

The agent saves to **both** Ogham (fast semantic recall) and Obsidian `brain/` (human-readable, curated):

| Event | Ogham | Obsidian |
|---|---|---|
| Non-trivial bug fixed | `ogham store "bug: <desc>"` | Append to `brain/Gotchas.md` |
| Architectural decision | `ogham store "decision: X over Y because Z"` | Append to `brain/KeyDecisions.md` |
| Pattern established | `ogham store "pattern: <desc>"` | Append to `brain/Patterns.md` |
| Session ends | `ogham hooks inscribe` | Archive completed `work/active/` notes |

---

### 7. Wrap-up

When you say *"wrap up"* the agent will:
1. Promote session learnings to `brain/` notes
2. Archive completed `work/active/` notes to `work/archive/YYYY/`
3. Run `ogham hooks inscribe` to save the session summary
4. Report what was saved

---

## Prerequisites

| Requirement | Notes |
|---|---|
| **Linux** (Ubuntu/Debian/Mint) or **macOS** | Apple Silicon and Intel both supported |
| **Docker** | Installed automatically if missing |
| **Obsidian** | Install manually from [obsidian.md](https://obsidian.md); enable the *Local REST API* community plugin; copy the API key |
| **opencode** | The AI coding agent this ADK augments — [opencode.ai](https://opencode.ai) |

---

## Configuration

Copy `.env.dist` to `.env` (done automatically by `make up`) and set:

```bash
POSTGRES_PASSWORD=your-secure-password
OBSIDIAN_API_KEY=your-obsidian-local-rest-api-key
```

The Obsidian API key comes from: *Obsidian → Settings → Community Plugins → Local REST API → API Key*.

---

## Make targets

| Target                  | Description                                        |
|-------------------------|----------------------------------------------------|
| `make up`               | Install host tools + start Docker services         |
| `make down`             | Stop Docker services                               |
| `make restart`          | `down` then `up`                                   |
| `make purge`            | Stop services and delete all volumes (destructive) |
| `make status`           | Requered tools installation status                 |
| `make init PROJ=<path>` | Initialise a project to use this ADK               |

---

## Repository layout

```
bin/
  init.sh                    # project initialiser (brain scaffold + symlinks)

src/
  context/                   # agent instruction docs (loaded into every project)
    ogham.md                 # how to use Ogham
    graphify.md              # how to use Graphify
    cass.md                  # how to use cass
    obsidian.md              # how to use the Obsidian vault
    codebase-index.md        # how to use the codebase index
  skills/
    memory-stack/SKILL.md    # session-start memory bootstrap skill
    obsidian-vault/SKILL.md  # vault read/write/wrap-up skill
  install/
    run.sh                   # orchestrator: collect inputs → install tools → write configs
    functions/               # shared bash library (colors, stdout, state, os, apt)
    homebrew/install.sh
    docker/install.sh
    python/install.sh        # installs uv
    nodejs/install.sh
    ogham/                   # ogham binary + config + FlashRank reranking
    graphify/                # graphify binary + per-project git hook setup
    cass/                    # cass binary + initial index build
    rtk/                     # RTK binary + opencode plugin wiring
    opencode/                # opencode.json, AGENTS.md, and codebase-index config
    obsidian/                # vault scaffold templates (NorthStar, KeyDecisions, …)
    shell/write-env.sh       # shell profile PATH additions
  docker/
    initdb/ogham-schema.sql  # Postgres schema (applied automatically on first start)

storage/                     # per-project brain notes (git-ignored content)
  <project-name>/brain/      # NorthStar, KeyDecisions, Patterns, Gotchas

docker-compose.yml           # postgres, ollama, ollama-init, obsidian-mcp
.env.dist                    # template for .env
Makefile                     # up, down, purge, restart, init
```
