# Telamon

A harness for agentic software development.

Everything a developer needs to get the best out of LLMs and coding agents — 
installed once, shared across every project and tailored for every project.

---

## Overview

Telamon is a **local infrastructure kit** that installs, wires up, and manages a suite of AI-augmentation 
tools for software development. It provides:

- **Persistent agent memory** — the agent remembers decisions, bugs, and patterns across sessions and projects
- **Codebase understanding** — semantic code search and a structural knowledge graph
- **Curated knowledge vault** — human-readable notes that survive model resets
- **Session recall** — searchable history of every past agent conversation
- **Automatic session capture** — learnings are promoted to memory before context is compacted
- **Token efficiency** — automatic compression of context sent to the LLM

All tools run locally. No data leaves your machine.

---

## Tools

### Tier 1 — Highest ROI
- [Ogham MCP](https://ogham-mcp.dev) + Postgres + Ollama
  The single biggest gain for multi-project work. Large codebases accumulate years of tribal knowledge,
  without persistent memory the agent rediscovers all of it every session.
- Intelephense LSP
  Already built into OpenCode, zero extra setup.
  Real-time diagnostics mean the agent catches type errors, undefined methods, and wrong signatures
  inline rather than running the code to find out. For specifically this matters more than most languages
  because's type system is optional — without LSP the agent guesses a lot.
- AGENTS.md per project
  A well-written AGENTS.md with your stack versions, framework conventions, database patterns,
  and key contacts is worth more than any indexing tool on a project the agent hasn't seen before.

### Tier 2 — High value, worth the setup cost
- [Graphify](https://github.com/safishamsi/graphify)
  Particularly valuable for large legacy codebases where nobody has a complete mental model anymore.
  God nodes alone — knowing which classes everything routes through — prevents the agent from making changes in the wrong place.
  The OpenCode plugin means it fires automatically. One upfront LLM cost, then git hooks keep it current.
- [RTK](https://github.com/rtk-ai/rtk)
  Removes useless tokens from commonly used cli tools output.
  Highest ROI for token efficiency — zero config, immediate, compounds with all other tools
- [opencode-codebase-index](https://github.com/Helweg/opencode-codebase-index)
  Complements Graphify. Graphify tells you the structure, codebase-index lets you find code by meaning.
  "Find all places we handle currency conversion" works even if the functions aren't named obviously.
  Each project gets its own local index.

### Tier 3 — Useful
- [Cass](https://github.com/dicklesworthstone/coding_agent_session_search)
  Uses the history of past sessions to draw from.
- [QMD](https://github.com/tobi/qmd)
  Semantic search over the Obsidian vault using local GGUF models. The `bootstrap/` folder is excluded (it's loaded directly like AGENTS.md); `brain/`, `work/`, `reference/`, and `thinking/` are each a separate collection. Exposed as an MCP server.
- [Obsidian MCP](https://hub.docker.com/r/oleksandrkucherenko/obsidian-mcp) & [Obsidian Mind](https://github.com/breferrari/obsidian-mind?tab=readme-ov-file)
  High value if you actually maintain notes. If nobody writes docs it adds nothing.
- Specialized agents
  The gains from routing planning to a smarter model and execution to a cheaper one compound with project size.

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

Builds a structural knowledge graph of the codebase. Identifies god nodes, architectural layers, call relationships, and module boundaries. 
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
Each project gets its own vault subfolder. Files in `bootstrap/` are **always loaded into context** — their content is available to the agent as if it were written directly in `AGENTS.md`.

```
<project>/bootstrap/       ← always-on context (treated as part of AGENTS.md)
<project>/brain/
  memories.md      ← index of memory topics
  key_decisions.md ← architectural decisions with rationale
  patterns.md      ← established codebase conventions
  gotchas.md       ← traps, constraints, known issues
<project>/work/
  active/          ← in-progress work notes
  archive/         ← completed work notes
  incidents/       ← incident docs
<project>/reference/  ← architecture maps, flow docs
<project>/thinking/   ← scratchpad for drafts
```

Obsidian must be installed separately (see [Prerequisites](#prerequisites)).

---

### 🗂️ cass — Agent Session History Search
[cass](https://github.com/dicklesworthstone/coding_agent_session_search)

Indexes past agent session conversations and makes them full-text searchable. 
Useful for recovering context from previous sessions: *"what did we decide about the payment flow last week?"*

- Built once with `cass index --full`; a **post-commit git hook** installed by `make init` runs `cass index` incrementally after every commit to keep the index current
- Search with `cass search --robot "<topic>"` (the `--robot` flag is required — bare `cass search` launches a blocking interactive TUI)

---

### 🔎 QMD — Vault Semantic Search
[qmd](https://github.com/tobi/qmd)

Provides semantic (vector) search over Telamon Obsidian vault using **fully local GGUF models** (~2 GB, auto-downloaded on first use). Stores a global index at `~/.cache/qmd/index.sqlite`.

- One named collection per vault section: `<project>-brain`, `<project>-work`, `<project>-reference`, `<project>-thinking`
- The `bootstrap/` folder is intentionally excluded — it is already loaded via AGENTS.md and does not benefit from search
- Exposed as an MCP server (`qmd mcp`) with `query`, `get`, `multi_get`, and `status` tools
- Search by natural language question: `qmd query "what did we decide about caching?" -n 10`
- Use **before** reading vault files directly to avoid redundant context loading
- `qmd update && qmd embed` keeps the index current (fast incremental refresh)

---

### 📸 Session Capture — Automatic Memory Promotion

An OpenCode plugin that fires after every completed agent turn (`session.idle`) and on explicit wrap-up. 
It promotes session learnings to the vault's `brain/` notes and Ogham automatically — no manual intervention needed.

- **Idle trigger**: fires after every agent turn; throttled to at most once per 30 minutes so it doesn't interrupt active work
- **Wrap-up trigger**: say *"wrap up"* to run a full capture pass at any time
- **Infinite-loop safe**: watermark is written before the capture prompt is sent, so the agent's response to the capture request doesn't re-trigger the plugin
- **Per-worktree watermark**: tracks what has already been captured so concurrent agents in different git worktrees don't duplicate entries
- Routes content to the right destination automatically: decisions → `key_decisions.md`, patterns → `patterns.md`, bugs → `gotchas.md`, etc.

---

### ⚡ RTK — Token Compression Proxy
[rtk](https://github.com/rtk-ai/rtk)

Transparently compresses bash command output before it reaches the LLM, reducing token consumption and cost. 
Installed as an opencode plugin that auto-patches shell commands.

- Installed globally and wired into opencode automatically (`rtk init -g --opencode --auto-patch`)
- No configuration needed; works transparently

---

### 🪨 Caveman — Token-Efficient Communication Mode
[caveman](https://github.com/JuliusBrussee/caveman)

A skill that switches the agent into an ultra-compressed communication mode — ~75% token reduction while keeping full technical accuracy. Useful for long sessions or when you want brief, direct answers.

- Activate by saying *"caveman mode"*, *"less tokens"*, or `/caveman`
- Supports intensity levels: `lite`, `full` (default), `ultra`, `wenyan-lite`, `wenyan-full`, `wenyan-ultra`
- Automatically drops filler, articles, and pleasantries; technical terms and code blocks are unchanged
- Deactivate with *"stop caveman"* or *"normal mode"*

---

### 🐋 Infrastructure Services (Docker)

| Service | Image | Purpose |
|---|---|---|
| `ogham-postgres` | `pgvector/pgvector:pg17` | Vector database for Ogham memory |
| `telamon-ollama` | `ollama/ollama:latest` | Local embedding model server |
| `telamon-ollama-init` | `ollama/ollama:latest` | One-shot job: pulls `nomic-embed-text` on first start |

> **Obsidian MCP** runs on-demand via `docker run` (not a persistent service) so it does not crash when Obsidian is not running.

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
│                                                                 │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │              OpenCode Plugins (always-on)                  │  │
│  │  session-capture  ·  graphify  ·  rtk                      │  │
│  └────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### What each tool provides at each stage

| Stage | Tool | Role |
|---|---|---|
| **Session start** | Ogham | Recalls past decisions, bugs, and patterns for this project |
| **Session start** | Obsidian `brain/` | Loads goals, decisions, patterns, and known gotchas |
| **Session start** | QMD | Semantic vault search — surfaces related context before diving in |
| **Understanding code** | Graphify | Structural map: layers, god nodes, module relationships |
| **Finding code** | Codebase Index | Semantic search: *"where is the auth logic?"* |
| **Finding vault notes** | QMD | Semantic vault search: *"did we ever deal with X?"* |
| **Recovering past context** | cass | Searches previous agent session transcripts |
| **Writing code** | RTK | Compresses bash output to save tokens |
| **Long sessions** | Caveman | Reduces response verbosity ~75% on demand |
| **After significant work** | Ogham | Stores new decisions, patterns, bug fixes |
| **After significant work** | Obsidian | Promotes learnings to `brain/` notes |
| **After each agent turn** | Session Capture | Auto-promotes learnings every 30 min (throttled); runs after `session.idle` |
| **End of session** | Ogham + Obsidian | Inscribes session summary; archives completed work notes |

---

## Developer Workflow

### 1. One-time: Clone and start Telamon

```bash
git clone <this-repo> ~/telamon
cd ~/telamon
make up
```

`make up` will:
1. Copy `.env.dist` → `.env` (if not present)
2. Install prerequisite host tools (Homebrew, Docker) — `--pre-docker` phase
3. Start Docker services (`postgres`, `ollama`)
4. Install remaining tools (opencode, Ogham, Graphify, cass, RTK, codebase-index, Obsidian MCP) — `--post-docker` phase

If `.ai/telamon/telamon.ini` exists with `project_name` set, the installer reads it silently (no prompts for project name/profile). If `.env` already has `POSTGRES_PASSWORD` set, the password prompt is also skipped.

> The installer is **idempotent** — safe to re-run at any time. Already-installed tools are skipped.

---

### 2. One-time per project: Initialise

```bash
make init PROJ=path/to/your-project
```

This will:
- Create the full Obsidian vault at `storage/obsidian/<project-name>/` with:
  - `bootstrap/` (always-on context files)
  - `brain/` notes (`memories.md`, `key_decisions.md`, `patterns.md`, `gotchas.md`)
  - `work/active/`, `work/archive/`, `work/incidents/` folders
  - `reference/` and `thinking/` folders
- Symlink `<project>/.opencode/skills/telamon` → `<telamon-root>/src/skills` (agent skills)
- Write `<project>/.ai/telamon/telamon.ini` with the project name variable
- Install the **Graphify** git hook and OpenCode plugin in the project
- Install the **session-capture** OpenCode plugin in the project (auto-captures before compaction)
- Install the **cass** post-commit git hook in the project (incremental index after every commit)
- Register **QMD** vault collections (`<project>-brain`, `-work`, `-reference`, `-thinking`) and build the initial semantic index

After this, when `opencode` starts in the project, it automatically loads Telamon context and skills.

---

### 3. Every day: Start Telamon

```bash
cd ~/telamon
make up       # if not already running
```

Check status at any time:

```bash
make status    # quick installation status
make doctor    # comprehensive health check (connectivity, secrets, config)
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
- cass index (first time only): `cass index --full`

Then run QMD incremental refresh and surface recent context:
```bash
qmd update && qmd embed
qmd query "what patterns and gotchas should I know" -n 5
```

---

### 5. During work

The agent automatically:
- Searches Ogham before repeating known work: `ogham search "<topic>"`
- Searches the codebase semantically via the codebase-index MCP
- Queries Graphify for architectural context: `graphify query "<question>"`
- Searches past sessions when needed: `cass search --robot "<topic>"`
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

The **session-capture plugin** handles this automatically before every compaction. On explicit wrap-up it also presents a summary of what was saved.

---

### 7. Wrap-up

When you say *"wrap up"* the agent will:
1. Promote session learnings to `brain/` notes
2. Archive completed `work/active/` notes to `work/archive/YYYY/`
3. Run `ogham hooks inscribe` to save the session summary
4. Report what was saved

> This also runs automatically before every context compaction via the session-capture plugin.

---

## Prerequisites

| Requirement | Notes |
|---|---|
| **Linux** (Ubuntu/Debian/Mint) or **macOS** | Apple Silicon and Intel both supported |
| **Docker** | Installed automatically if missing |
| **Obsidian** | Install manually from [obsidian.md](https://obsidian.md); enable the *Local REST API* community plugin; copy the API key |
| **opencode** | The AI coding agent Telamon augments — [opencode.ai](https://opencode.ai) |

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

| Target                  | Description                                                     |
|-------------------------|-----------------------------------------------------------------|
| `make up`               | Install host tools + start Docker services                      |
| `make down`             | Stop Docker services                                            |
| `make restart`          | `down` then `up`                                                |
| `make purge`            | Stop services and delete all volumes (destructive)              |
| `make status`           | Quick installation status of all Telamon tools                      |
| `make doctor`           | Comprehensive health check (connectivity, config, secrets)      |
| `make update`           | Upgrade all Telamon-managed tools to their latest versions          |
| `make init PROJ=<path>` | Initialise a project to use Telamon                            |
| `make test`             | Run the full test suite (make up + init dummy project + assert) |

---

## Repository layout

```
bin/
  init.sh                    # project initialiser (brain scaffold + symlinks + plugins)
  install.sh                 # orchestrator: --pre-docker, --post-docker phases
  update.sh                  # upgrades all Telamon-managed tools to latest versions
  doctor.sh                  # comprehensive health check (connectivity, config, secrets)
  status.sh                  # quick installation status of all Telamon tools

src/
  context/                   # agent instruction docs (loaded into every project)
    ogham.md                 # how to use Ogham
    graphify.md              # how to use Graphify
    cass.md                  # how to use cass
    obsidian.md              # how to use the Obsidian vault
    codebase-index.md        # how to use the codebase index
  skills/
    memory/
      memory-stack/SKILL.md  # session-start memory bootstrap skill
      session-capture/SKILL.md  # pre-compaction + wrap-up memory capture skill
      cass/SKILL.md          # cass usage skill (downloaded from upstream on install/update)
      qmd/SKILL.md           # QMD vault semantic search skill (downloaded or bundled)
      graphify/SKILL.md      # codebase knowledge graph skill
      obsidian-vault/        # vault skill + vault scaffold template
        SKILL.md
        _tmpl/               # full vault template (copied per project on make init)
          bootstrap/         # always-on context files (loaded like AGENTS.md)
          brain/             # memories, key_decisions, patterns, gotchas
          work/active|archive|incidents/
          reference/
          thinking/
    dev/                     # agentic workflow skills
      agent-communication/   # inter-agent communication protocol
      caveman/SKILL.md       # token-efficient communication mode (downloaded from upstream)
      changeset-review/      # code review against a plan
      codebase-audit/        # holistic codebase health review
      create-adr/            # architecture decision records
      create-use-case/       # CQRS command/handler generation
      evaluation/            # post-iteration quality assessment
      exception-handling/    # structured error recovery for agent failures
      implementation-planning/
      memory-management/
      optimize-instructions/
      plan-execution/
      plan-review/
      plan-summary/
      test-reporting/
      ui-specification/
      ux-design/
      workflow.implement-story/
      workflow.plan-story/
    addyosmani/              # general engineering skills (from addyosmani/agent-skills)
      api-and-interface-design/
      browser-testing-with-devtools/
      ci-cd-and-automation/
      code-review-and-quality/
      code-simplification/
      debugging-and-error-recovery/
      frontend-ui-engineering/
      git-workflow-and-versioning/
      incremental-implementation/
      performance-optimization/
      planning-and-task-breakdown/
      security-and-hardening/
      shipping-and-launch/
      spec-driven-development/
      test-driven-development/
      ... (and more)
  install/
    functions/               # shared bash library (colors, stdout, state, os, apt, opencode)
    homebrew/install.sh
    docker/install.sh
    python/install.sh        # installs uv
    nodejs/install.sh
    ogham/                   # ogham binary + config + FlashRank reranking
    graphify/                # graphify binary + per-project git hook + opencode plugin
    cass/                    # cass binary + skill download + init.sh (post-commit hook)
    caveman/                 # caveman skill download (no binary)
    qmd/                     # qmd binary install + skill download + init.sh (vault collections)
    rtk/                     # RTK binary + opencode plugin wiring
    opencode/                # opencode binary + shared storage/opencode.jsonc template
    codebase-index/          # MCP registration + per-project codebase-index.json
    obsidian/                # Obsidian binary install + MCP registration
    session-capture/         # session-capture opencode plugin + init.sh
    shell/write-env.sh       # shell profile PATH additions

storage/                     # runtime data — git-ignored except opencode.jsonc
  opencode.jsonc             # shared opencode config (tracked); projects symlink to this
  secrets/                   # one plain-text file per secret (git-ignored)
  state/                     # installer state (saved inputs, completed steps)
  pgdata/                    # Postgres data volume (git-ignored)
  ollama/                    # Ollama model cache (git-ignored)
  graphify/                  # graphify output cache (git-ignored)
  obsidian/<project-name>/   # per-project Obsidian vault
    bootstrap/               # always-on context (loaded like AGENTS.md)
    brain/                   # memories, key_decisions, patterns, gotchas
    work/active/             # in-progress work notes
    work/archive/            # completed work notes
    work/incidents/          # incident docs
    reference/               # architecture maps, flow docs
    thinking/                # scratchpad for drafts

docker-compose.yml           # postgres, ollama, ollama-init
.env.dist                    # template for .env (POSTGRES_PASSWORD, OBSIDIAN_API_KEY)
Makefile                     # up, down, purge, restart, status, doctor, update, init, test
```

## Acknowledgements and References

- [Caveman](https://github.com/JuliusBrussee/caveman)
- [Obsidian Mind](https://github.com/breferrari/obsidian-mind?tab=readme-ov-file)
- [Cass](https://github.com/dicklesworthstone/coding_agent_session_search)
- [QMD](https://github.com/tobi/qmd)
- [Addy Osmani Skills](https://github.com/addyosmani/agent-skills)
- [Codebase Index](https://github.com/Helweg/opencode-codebase-index)
- [Graphify](https://github.com/safishamsi/graphify)
- [Ogham MCP](https://ogham-mcp.dev)
- [RTK](https://github.com/rtk-ai/rtk)
