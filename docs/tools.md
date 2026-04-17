# Tools

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

## Obsidian MCP — Curated Knowledge Vault

[obsidian-mcp](https://github.com/oleksandrkucherenko/obsidian-mcp)

Bridges the agent to an **Obsidian** vault containing long-lived, human-curated knowledge:
project goals, architectural decisions, codebase patterns, and known gotchas.
Each project gets its own vault subfolder. Files in `bootstrap/` are **always loaded into context** — their content is available to the agent as if it were written directly in `AGENTS.md`.

```
<project>/bootstrap/       <- always-on context (treated as part of AGENTS.md)
<project>/brain/
  memories.md      <- index of memory topics
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

## Specialized Agent Skills

Telamon ships a library of skills that guide the agent through structured workflows:

### Memory & Context Skills
- **memory-stack** — session-start memory bootstrap (loads all memory tools)
- **session-capture** — pre-compaction + wrap-up memory capture
- **obsidian-vault** — vault read/write protocol
- **qmd** — vault semantic search skill
- **cass** — session history search skill
- **graphify** — codebase knowledge graph skill

### Development Workflow Skills
- **agent-communication** — inter-agent communication protocol
- **workflow.plan-story** — plans a user story (backlog + architecture spec)
- **workflow.implement-story** — implements an approved plan (tester -> developer -> reviewer cycle)
- **implementation-planning** — creates implementation plans from a brief
- **plan-execution** — executes plans step-by-step
- **plan-review** — reviews an architect's plan
- **changeset-review** — code review against a plan
- **codebase-audit** — holistic codebase health review
- **create-adr** — architecture decision records
- **create-use-case** — CQRS command/handler generation
- **evaluation** — post-iteration quality assessment
- **exception-handling** — structured error recovery for agent failures
- **memory-management** — project memories.md management
- **optimize-instructions** — agent instruction file optimization
- **test-reporting** — test result documentation

### General Engineering Skills (from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills))
- api-and-interface-design, browser-testing-with-devtools, ci-cd-and-automation, code-review-and-quality, code-simplification, context-engineering, debugging-and-error-recovery, deprecation-and-migration, documentation-and-adrs, frontend-ui-engineering, git-workflow-and-versioning, idea-refine, incremental-implementation, performance-optimization, planning-and-task-breakdown, security-and-hardening, shipping-and-launch, spec-driven-development, test-driven-development, using-agent-skills

---

## Infrastructure Services (Docker)

| Service | Image | Purpose |
|---|---|---|
| `ogham-postgres` | `pgvector/pgvector:pg17` | Vector database for Ogham memory |
| `telamon-ollama` | `ollama/ollama:latest` | Local embedding model server |
| `telamon-ollama-init` | `ollama/ollama:latest` | One-shot job: pulls `nomic-embed-text` on first start |

> **Obsidian MCP** runs on-demand via `docker run` (not a persistent service) so it does not crash when Obsidian is not running.

---

## Tool Priority Guide

### Tier 1 — Highest ROI
- **Ogham MCP** + Postgres + Ollama — The single biggest gain for multi-project work. Large codebases accumulate years of tribal knowledge; without persistent memory the agent rediscovers all of it every session.
- **Intelephense LSP** — Already built into OpenCode, zero extra setup. Real-time diagnostics mean the agent catches type errors, undefined methods, and wrong signatures inline.
- **AGENTS.md per project** — A well-written AGENTS.md with your stack versions, framework conventions, database patterns, and key contacts is worth more than any indexing tool on a project the agent hasn't seen before.

### Tier 2 — High value, worth the setup cost
- **Graphify** — Fully automatic codebase knowledge graph. Particularly valuable for large legacy codebases where nobody has a complete mental model anymore.
- **RTK** — Highest ROI for token efficiency — zero config, immediate, compounds with all other tools.
- **Codebase Index** — Complements Graphify. Find code by meaning, not just by name.

### Tier 3 — Useful
- **Cass** — Uses the history of past sessions to draw from.
- **QMD** — Semantic search over the Obsidian vault using local models.
- **Obsidian MCP** — High value if you actually maintain notes. If nobody writes docs it adds nothing.
- **Specialized agents** — The gains from routing planning to a smarter model and execution to a cheaper one compound with project size.
