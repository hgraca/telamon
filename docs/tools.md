---
layout: page
title: Tools
description: Detailed descriptions of every tool Telamon installs and manages.
nav_section: docs
---

Detailed descriptions of every tool Telamon installs and manages.

---

## Ogham MCP — Semantic Agent Memory

[ogham-mcp](https://github.com/ogham-mcp/ogham-mcp)

Stores and retrieves decisions, bugs, and patterns using semantic vector search.
Backed by a local **Postgres + pgvector** database and **Ollama** embeddings (`nomic-embed-text`).
Exposed to the agent via an MCP server.

- Persists knowledge across sessions and projects using named profiles
- Searches by meaning, not exact text
- FlashRank cross-encoder reranking improves result precision (~+8pp MRR)

**Agent commands (MCP tools):** `ogham switch_profile`, `ogham store_memory`, `ogham hybrid_search`, `ogham explore_knowledge`, `ogham list_recent`, `ogham find_related`
**CLI equivalents:** `ogham use <profile>`, `ogham store "..."`, `ogham search "..."`

---

## Graphify — Codebase Knowledge Graph

[graphify](https://github.com/safishamsi/graphify)

Builds a structural knowledge graph of the codebase. Identifies god nodes, architectural layers, call relationships, and module boundaries.
Fully automatic — built during `make init`, updated every 30 minutes, and exposed to the agent via an MCP server.

- **Auto-build**: `make init` builds the graph automatically. Existing projects that already have a graph skip the build.
- **Scheduled updates**: A platform-native timer (systemd on Linux, launchd on macOS) runs `graphify . --update` every 30 minutes — no git hooks needed.
- **MCP server**: Exposed as an on-demand MCP server (`graphify.serve`) with tools: `query_graph`, `get_node`, `get_neighbors`, `get_community`, `god_nodes`, `graph_stats`, `shortest_path`.
- **Context injection**: An opencode plugin extracts god nodes, communities, and surprising connections from `GRAPH_REPORT.md` and injects them into the first bash tool call of each session — agents start every session with architectural awareness.
- **Per-project storage**: Each project gets its own graph at `storage/graphify/<project-name>/`, preventing cross-project overwrites.

Particularly valuable for large legacy codebases where nobody has a complete mental model anymore.
God nodes alone — knowing which classes everything routes through — prevents the agent from making changes in the wrong place.

**Manage scheduled updates:**
- Linux: `systemctl --user status graphify-update-<project-name>.timer`
- macOS: `launchctl list | grep graphify-update-<project-name>`
- Remove: `bash src/install/graphify/schedule.sh --remove <project-name>`

---

## Codebase Index — Semantic Code Search

[opencode-codebase-index](https://github.com/Helweg/opencode-codebase-index)

Indexes the project's source code using Ollama embeddings, enabling natural-language semantic search over the codebase.
Built once per project; a file watcher maintains it automatically.

- Ask naturally: *"find the authentication logic"*, *"where is the payment handler?"*
- Results ranked by semantic similarity
- Exposed as an MCP tool (`index_codebase` / `search_codebase`)

Complements Graphify: Graphify tells you the structure, codebase-index lets you find code by meaning.
*"Find all places we handle currency conversion"* works even if the functions aren't named obviously.

---

## Repomix — Directory Context Packer

[repomix](https://github.com/yamadashy/repomix)

Packs directory contents into a single compressed context dump using Tree-sitter-aware chunking.
Reduces token consumption by ~70% compared to reading files individually.
Exposed to the agent via an MCP server (`npx -y repomix --mcp`).

- **Batch reading**: replaces 5+ individual file reads with a single structured dump
- **Tree-sitter compression**: language-aware chunking preserves code structure while reducing size
- **Security scanning**: detects secrets and sensitive patterns before context is sent to the model
- **Per-project config**: behaviour controlled by `repomix.config.json` at the project root (created by `init.sh`)

Use when exploring an unfamiliar directory, reading a module's full source, or gathering context across related files.
Do **not** combine with codebase-index for the same files — redundant context wastes tokens.

---

## promptfoo — Agent Evaluation Framework

[promptfoo](https://github.com/promptfoo/promptfoo)

Automated quality checks for agent behavior. Tests request classification, plan structure, code review quality, and skill activation. Runs via `npx -y promptfoo` — no global install needed.

- **Declarative YAML configs**: each eval is a standalone YAML file with prompts, test cases, and assertions
- **`opencode:sdk` provider**: starts an ephemeral opencode server per eval — reproducible, no state leakage
- **Multiple assertion types**: JavaScript checks, LLM-as-judge rubrics, cost/latency thresholds, trajectory analysis
- **Web UI**: `npx -y promptfoo view` shows interactive results dashboard
- **Per-project evals**: configs live in `test/eval/` alongside the project they test

Use after changing agent instructions, adding skills, or before merging behavior changes.

**Commands:** `cd test/eval && npx -y promptfoo eval`, `npx -y promptfoo eval -c evals/<name>.yaml`, `npx -y promptfoo view`
**Slash command:** `/eval`

---

## Obsidian MCP — Curated Knowledge Vault

[obsidian-mcp](https://github.com/oleksandrkucherenko/obsidian-mcp)

Bridges the agent to an **Obsidian** vault containing long-lived, human-curated knowledge:
project goals, architectural decisions, codebase patterns, and known gotchas.
Each project gets its own vault subfolder. Files in `bootstrap/` are **always loaded into context** — their content is available to the agent as if it were written directly in `AGENTS.md`.

```
<project>/bootstrap/       <- always-on context (treated as part of AGENTS.md)
<project>/brain/
  memories.md      <- categorized lessons learned
  key_decisions.md <- architectural decisions with rationale
  patterns.md      <- established codebase conventions
  gotchas.md       <- traps, constraints, known issues
<project>/work/
  active/          <- in-progress work notes
  archive/         <- completed work notes
  incidents/       <- incident docs
<project>/reference/  <- architecture maps, flow docs
<project>/thinking/   <- scratchpad for drafts
```

High value if you actually maintain notes. If nobody writes docs it adds nothing.

Obsidian is installed automatically by `make up`. After install, the *Local REST API* community plugin must be enabled manually — the installer walks you through the steps.

---

## QMD — Vault Semantic Search

[qmd](https://github.com/tobi/qmd)

Provides semantic (vector) search over the Obsidian vault using **fully local GGUF models** (~2 GB, auto-downloaded on first use). Stores a global index at `~/.cache/qmd/index.sqlite`.

- One named collection per vault section: `<project>-brain`, `<project>-work`, `<project>-reference`, `<project>-thinking`
- The `bootstrap/` folder is intentionally excluded — it is already loaded via AGENTS.md and does not benefit from search
- Exposed as an MCP server (`qmd mcp`) with `query`, `get`, `multi_get`, and `status` tools
- Search by natural language question: `qmd query "what did we decide about caching?" -n 10`
- Use **before** reading vault files directly to avoid redundant context loading
- `qmd update && qmd embed` keeps the index current (fast incremental refresh)

---

## Cass — Agent Session History Search

[cass](https://github.com/dicklesworthstone/coding_agent_session_search)

Indexes past agent session conversations and makes them full-text searchable.
Useful for recovering context from previous sessions: *"what did we decide about the payment flow last week?"*

- Built once with `cass index --full`; a **scheduled background job** (every 30 min) runs `cass index` incrementally to keep the index current
- Search with `cass search --robot "<topic>"` (the `--robot` flag is required — bare `cass search` launches a blocking interactive TUI)

**Manage scheduled updates:**
- Linux: `systemctl --user status cass-index.timer`
- macOS: `launchctl list | grep cass-index`
- Remove: `bash src/install/cass/schedule.sh --remove`

---

## Session Capture — Automatic Memory Promotion

An OpenCode plugin that fires after every completed agent turn (`session.idle`) and on explicit wrap-up.
It promotes session learnings to the vault's `brain/` notes and Ogham automatically — no manual intervention needed.

- **Idle trigger**: fires after every agent turn; throttled to at most once per 30 minutes so it doesn't interrupt active work
- **Wrap-up trigger**: say *"wrap up"* to run a full capture pass at any time
- **Infinite-loop safe**: watermark is written before the capture prompt is sent, so the agent's response to the capture request doesn't re-trigger the plugin
- **Per-worktree watermark**: tracks what has already been captured so concurrent agents in different git worktrees don't duplicate entries
- Routes content to the right destination automatically: decisions -> `key_decisions.md`, patterns -> `patterns.md`, bugs -> `gotchas.md`, etc.

---

## Diff Context — Session-Aware Git Change Summary

An OpenCode plugin that injects a summary of recent git changes (commits + diffstat) on the first bash tool call of each session.

- **Automatic**: fires on the first bash call — no manual steps
- **Watermark-aware**: reads the session-capture watermark to know which changes are new since the last session
- **Fallback**: when no watermark exists (first session), shows the last 10 commits
- **Budget-capped**: max 30 commit lines + 20 diffstat lines (50 total), ensuring diffstat always gets space
- **Improvement over graphify pattern**: sets `injected=true` even on no-op, preventing retries on every bash call
- **Data flow**: session-capture writes watermark → diff-context reads it → injects summary on first bash call

---

## RTK — Token Compression Proxy

[rtk](https://github.com/rtk-ai/rtk)

Transparently compresses bash command output before it reaches the LLM, reducing token consumption and cost.
Installed as an opencode plugin that auto-patches shell commands.

- Installed globally and wired into opencode automatically (`rtk init -g --opencode --auto-patch`)
- No configuration needed; works transparently
- Highest ROI for token efficiency — zero config, immediate, compounds with all other tools

---

## Caveman — Token-Efficient Communication Mode

[caveman](https://github.com/JuliusBrussee/caveman)

A skill that switches the agent into an ultra-compressed communication mode — ~75% token reduction while keeping full technical accuracy. Useful for long sessions or when you want brief, direct answers.

- Activate by saying *"caveman mode"*, *"less tokens"*, or `/caveman`
- Supports intensity levels: `lite`, `full` (default), `ultra`, `wenyan-lite`, `wenyan-full`, `wenyan-ultra`
- Automatically drops filler, articles, and pleasantries; technical terms and code blocks are unchanged
- Deactivate with *"stop caveman"* or *"normal mode"*

---

## Langfuse — Observability (Optional)

[langfuse](https://langfuse.com)

Self-hosted LLM observability platform. Tracks token usage, latency, cost, and prompt/response pairs across agent sessions.
Enabled by setting `LANGFUSE_ENABLED=true` in `.env`.

- **Profile-gated**: only starts when `LANGFUSE_ENABLED=true`
- Runs as a Docker Compose profile (`langfuse`) with four services: Postgres, Redis, ClickHouse, and the Langfuse web app
- Accessible at `http://localhost:4000` after startup
- Requires `LANGFUSE_SECRET` and `LANGFUSE_SALT` in `.env`

---

## Graphiti — Temporal Knowledge Graph (Optional)

[graphiti](https://github.com/getzep/graphiti)

Temporal knowledge graph backed by Neo4j. Stores entities and relationships with temporal metadata — useful for tracking how architectural decisions and codebase structure evolve over time.
Enabled by setting `GRAPHITI_ENABLED=true` in `.env`.

- **Profile-gated**: only starts when `GRAPHITI_ENABLED=true`
- Runs as a Docker Compose profile (`graphiti`) with Neo4j and the Graphiti API server
- Requires `NEO4J_PASSWORD` and `OPENAI_API_KEY` in `.env` (OpenAI used for entity extraction)
- Neo4j browser at `http://localhost:7474`, Graphiti API at `http://localhost:8001`

---

## MCP Integrations

Beyond Telamon-managed tools, the shared `storage/opencode.jsonc` registers several MCP servers available to every project:

| MCP Server | Purpose |
|---|---|
| **ast-grep** | Structural code search using AST patterns |
| **chrome-devtools** | Browser inspection and debugging via Chrome DevTools Protocol |
| **context7** | Up-to-date library and framework documentation lookup |
| **git** | Git operations (status, diff, commit, branch, etc.) |
| **github** | GitHub integration (issues, PRs, code search, reviews) |
| **grep.app** | Code search across public GitHub repositories |
| **laravel-boost** | Laravel Artisan commands, migrations, database queries, doc search |
| **playwright** | Browser automation and testing |
| **repomix** | Pack directory contents into compressed context (~70% token reduction) |
| **exa** | Web search |

These are configured in `storage/opencode.jsonc` and symlinked into each project by `make init`.

---

## Multi-Agent Roles

Telamon defines a team of specialized agents (in `src/agents/`), each with a focused responsibility:

| Agent | Role |
|---|---|
| **telamon** (orchestrator) | Classifies requests, delegates to specialists, leads planning and implementation workflows |
| **architect** | Designs technical plans and ADRs; does not write production code |
| **critic** | Audits codebase for inconsistencies, architectural erosion, and pattern drift |
| **developer** | Implements the architect's plan into production code |
| **po** (product owner) | Domain expert — owns backlog grooming, answers business and requirements questions |
| **reviewer** | Reviews changesets against the plan and project conventions |
| **security** | Security audits, threat modelling, vulnerability assessment, secure code review |
| **tester** | Validates implementations, writes and executes automated tests |
| **ui-designer** | Visual specs, design tokens, screen layouts |
| **ux-designer** | User flows, interaction specs, state definitions |

---

## Slash Commands

Telamon provides slash commands (in `src/commands/`) that trigger structured workflows:

| Command | Purpose |
|---|---|
| `/plan` | Plan a story or feature (backlog + architecture spec) |
| `/implement` | Implement an approved plan |
| `/story` | Plan and implement a story end-to-end |
| `/epic` | Break an epic into stories, plan and implement each |
| `/eval` | Run agent evaluations with promptfoo |
| `/dev` | Delegate a code task directly to the developer |
| `/test` | Write or run tests |
| `/review` | Review a code changeset |
| `/gh_review` | Review a GitHub pull request |
| `/archive` | Archive completed work notes |
| `/caveman` | Toggle token-efficient communication mode |
| `/vault-audit` | Audit the knowledge vault structure and content |

---

## Specialized Agent Skills

Telamon ships a library of skills that guide the agent through structured workflows:

### Memory & Context Skills
- **memory-management** — vault structure, routing, retrieval, writing, and quality rules
- **thinking** — scratch files, drafts, and WIP content management
- **recall-memories** — session-start memory bootstrap (loads all memory tools)
- **remember-lessons-learned** — continuous capture of decisions, patterns, bugs
- **remember-task** — post-task lesson capture to memories.md
- **remember-checkpoint** — pre-compaction state preservation
- **remember-session** — end-of-session wrap-up and promotion
- **qmd** — vault semantic search (initialization, querying, index maintenance)
- **ogham** — semantic agent memory (profile switching, storing, searching)
- **obsidian** — Obsidian MCP vault interaction (searching, reading, writing, linking)
- **cass** — session history search
- **graphify** — codebase knowledge graph

### Development Convention Skills
- **architecture-rules** — universal architecture rules (priorities, security, forbidden patterns)
- **explicit-architecture** — DDD + Hexagonal + CQRS layer structure and dependency rules
- **rest-conventions** — RESTful API conventions (URL structure, errors, pagination)
- **create-adr** — architecture decision records
- **create-use-case** — CQRS command/handler generation
- **documentation-rules** — repository documentation conventions
- **git-rules** — git commit conventions (gitignored paths, conventional commits)
- **makefile** — Makefile lifecycle commands
- **testing** — test commands, strategy, conventions
- **testing/promptfoo** — agent evaluation with promptfoo (running evals, adding test cases)
- **php-rules** — PHP coding rules (strict typing, enums, PHPDoc)
- **laravel** — Laravel conventions
- **message-bus** — PHP message bus integration

### Workflow Skills
- **agent-communication** — inter-agent communication protocol
- **plan-story** — plans a user story (backlog + architecture spec)
- **implement-story** — implements an approved plan (tester -> developer -> reviewer cycle)
- **epic** — breaks an epic into stories, plans and implements each
- **plan-implementation** — creates implementation plans from a brief
- **execute-plan** — executes plans step-by-step
- **review-plan** — reviews an architect's plan
- **review-changeset** — code review against a plan
- **review-security** — PHP security review (STRIDE, OWASP, vulnerability checklist)
- **audit-codebase** — holistic codebase health review
- **retrospective** — post-iteration quality assessment
- **summarize-plan** — produces planning summary after a planning stage
- **test-codebase** — test result documentation
- **exception-handling** — structured error recovery for agent failures
- **optimize-instructions** — agent instruction file optimization
- **ui-specification** — implementation-ready UI specifications
- **ux-design** — UX specifications and validation

### General Engineering Skills (from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills))
- api-and-interface-design, browser-testing-with-devtools, ci-cd-and-automation, code-review-and-quality, code-simplification, context-engineering, debugging-and-error-recovery, deprecation-and-migration, documentation-and-adrs, frontend-ui-engineering, git-workflow-and-versioning, idea-refine, incremental-implementation, performance-optimization, planning-and-task-breakdown, security-and-hardening, shipping-and-launch, source-driven-development, spec-driven-development, test-driven-development, using-agent-skills

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

Enabled by setting `LANGFUSE_ENABLED=true` in `.env`.

| Service | Image | Purpose |
|---|---|---|
| `telamon-langfuse-db` | `postgres:16` | Langfuse metadata database |
| `telamon-langfuse-redis` | `redis:7-alpine` | Langfuse cache |
| `telamon-langfuse-clickhouse` | `clickhouse/clickhouse-server:latest` | Langfuse analytics store |
| `telamon-langfuse-web` | `langfuse/langfuse:latest` | Langfuse web UI (port 4000) |

### Optional: Graphiti + Neo4j (profile: `graphiti`)

Enabled by setting `GRAPHITI_ENABLED=true` in `.env`.

| Service | Image | Purpose |
|---|---|---|
| `telamon-neo4j` | `neo4j:5` | Graph database for Graphiti |
| `telamon-graphiti` | `zepai/graphiti:latest` | Temporal knowledge graph API (port 8001) |

---

## Tool Priority Guide

### Tier 1 — Highest ROI
- **Ogham MCP** + Postgres + Ollama — The single biggest gain for multi-project work. Large codebases accumulate years of tribal knowledge; without persistent memory the agent rediscovers all of it every session.
- **Intelephense LSP** — Already built into OpenCode, zero extra setup. Real-time diagnostics mean the agent catches type errors, undefined methods, and wrong signatures inline.
- **AGENTS.md per project** — A well-written AGENTS.md with your stack versions, framework conventions, database patterns, and key contacts is worth more than any indexing tool on a project the agent hasn't seen before.

### Tier 2 — High value, worth the setup cost
- **Graphify** — Fully automatic codebase knowledge graph. Particularly valuable for large legacy codebases where nobody has a complete mental model anymore.
- **RTK** — Highest ROI for token efficiency — zero config, immediate, compounds with all other tools.
- **Repomix** — ~70% token reduction when reading multiple files from the same area. Use instead of individual file reads for 5+ files.
- **promptfoo** — Automated agent evaluation. Catches instruction regressions before they reach production.
- **Codebase Index** — Complements Graphify. Find code by meaning, not just by name.

### Tier 3 — Useful
- **Cass** — Uses the history of past sessions to draw from.
- **QMD** — Semantic search over the Obsidian vault using local models.
- **Obsidian MCP** — High value if you actually maintain notes. If nobody writes docs it adds nothing.
- **Specialized agents** — The gains from routing planning to a smarter model and execution to a cheaper one compound with project size.

### Optional — Situational
- **Langfuse** — Worth enabling when you need to track token costs across sessions or debug prompt quality.
- **Graphiti** — Worth enabling for projects where temporal evolution of architecture matters (requires OpenAI API key).
