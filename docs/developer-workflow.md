# Developer Workflow

Step-by-step guide to using Telamon day-to-day.

---

## 1. One-time: Clone and start Telamon

```bash
git clone <this-repo> ~/telamon
cd ~/telamon
make up
```

`make up` will:
1. Copy `.env.dist` -> `.env` (if not present)
2. Install prerequisite host tools (Homebrew, Docker) — `--pre-docker` phase
3. Start Docker services (`postgres`, `ollama`)
4. Install remaining tools (opencode, Ogham, Graphify, cass, RTK, codebase-index, Obsidian MCP) — `--post-docker` phase

If `.ai/telamon/telamon.ini` exists with `project_name` set, the installer reads it silently (no prompts for project name/profile). If `.env` already has `POSTGRES_PASSWORD` set, the password prompt is also skipped.

> The installer is **idempotent** — safe to re-run at any time. Already-installed tools are skipped.

---

## 2. One-time per project: Initialise

```bash
make init PROJ=path/to/your-project
```

This will:
- Create the full Obsidian vault at `storage/obsidian/<project-name>/` with:
  - `bootstrap/` (always-on context files)
  - `brain/` notes (`memories.md`, `key_decisions.md`, `patterns.md`, `gotchas.md`)
  - `work/active/`, `work/archive/`, `work/incidents/` folders
  - `reference/` and `thinking/` folders
- Symlink `<project>/.opencode/skills/telamon` -> `<telamon-root>/src/skills` (agent skills)
- Write `<project>/.ai/telamon/telamon.ini` with the project name variable
- Install the **Graphify** git hook and OpenCode plugin in the project
- Install the **session-capture** OpenCode plugin in the project (auto-captures before compaction)
- Schedule a **cass** background job to incrementally index agent sessions every 30 minutes
- Register **QMD** vault collections (`<project>-brain`, `-work`, `-reference`, `-thinking`) and build the initial semantic index

After this, when `opencode` starts in the project, it automatically loads Telamon context and skills.

---

## 3. Every day: Start Telamon

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

## 4. Every agent session: Automatic memory bootstrap

At the start of every session (via the `telamon.recall_memories` skill) **the agent will automatically**:

- Graphify plugin injects god nodes, communities, and surprising connections into the first tool call (no manual action needed)

```bash
ogham use <project-name>     # activate this project's memory profile (ogham switch_profile MCP tool)
ogham search "<topic>"        # surface relevant past context (ogham hybrid_search MCP tool)
```

Then check and build (once each, if missing):
- Codebase index: `index_codebase` tool
- cass index (first time only): `cass index --full`

Then run QMD vault index refresh and gather context (see the `telamon.qmd` skill for details):
```bash
qmd update && qmd embed
qmd query "what patterns and gotchas should I know" -n 5
```

---

## 5. During work

The agent automatically:
- Searches Ogham before repeating known work: `ogham search "<topic>"`
- Searches the codebase semantically via the codebase-index MCP
- Queries Graphify for architectural context via the Graphify MCP (god nodes, communities, graph queries)
- Searches past sessions when needed: `cass search --robot "<topic>"`
- Reads `brain/key_decisions.md`, `brain/patterns.md`, and `brain/gotchas.md` to stay aligned with project context

---

## 6. Saving knowledge

The agent saves to **both** Ogham (fast semantic recall) and Obsidian `brain/` (human-readable, curated):

| Event | Ogham | Obsidian |
|---|---|---|
| Non-trivial bug fixed | `ogham store "bug: <desc>"` | Append to `brain/gotchas.md` |
| Architectural decision | `ogham store "decision: X over Y because Z"` | Append to `brain/key_decisions.md` |
| Pattern established | `ogham store "pattern: <desc>"` | Append to `brain/patterns.md` |
| Session ends | `ogham store "session: <summary>"` (ogham store_memory MCP tool) | Archive completed `work/active/` notes |

The **session-capture plugin** handles this automatically before every compaction. On explicit wrap-up it also presents a summary of what was saved.

---

## 7. Wrap-up

When you say *"wrap up"* the agent will:
1. Promote session learnings to `brain/` notes
2. Archive completed `work/active/` notes to `work/archive/YYYY/`
3. Save to Ogham via `ogham store_memory` (MCP tool) or `ogham store` (CLI) — capture significant decisions, patterns, and bugs
4. Report what was saved

> This also runs automatically before every context compaction via the session-capture plugin.
