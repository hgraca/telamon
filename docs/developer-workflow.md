---
layout: page
title: Developer Workflow
description: Step-by-step guide to using Telamon day-to-day.
nav_section: docs
---

Everything you need to use Telamon day-to-day.

## Quick reference

```bash
# Install (one-time)
curl -fsSL https://raw.githubusercontent.com/hgraca/telamon/main/install.sh | bash

# Initialise a project (one-time per project)
telamon init path/to/your-project

# Start Telamon (daily)
telamon up

# Work
cd path/to/your-project && opencode

# When done, tell the agent "wrap up"
```

That's it. The agent handles memory, context, and knowledge capture automatically.

---

## The five steps in detail

### 1. Install Telamon (one-time)

```bash
curl -fsSL https://raw.githubusercontent.com/hgraca/telamon/main/install.sh | bash
```

After install, the `telamon` command is available globally. See [Commands](make-targets.md) for the full list.

> The installer is **idempotent** — safe to re-run at any time. Already-installed tools are skipped.

### 2. Initialise a project (one-time per project)

```bash
telamon init path/to/your-project
# or: cd path/to/your-project && telamon init
```

After this, opening `opencode` in the project automatically loads Telamon context and skills.

### 3. Start Telamon (daily)

```bash
telamon up
```

Check status at any time:

```bash
telamon status    # quick installation status
telamon doctor    # comprehensive health check
```

### 4. Work

Open your project in opencode and work normally. The agent uses Telamon's tools automatically — you don't need to do anything special.

### 5. Wrap up

When you're done, say *"wrap up"*. The agent saves session learnings and archives completed work.

> This also runs automatically before every context compaction, so nothing is lost even if you forget.

---

## Under the hood

### What the installer does

The curl script clones the repository to `~/.telamon` and runs `make up`, which:

1. Copies `.env.dist` → `.env` (if not present)
2. Installs prerequisite host tools (Homebrew, Docker) — pre-docker phase
3. Starts Docker services (Postgres, Ollama)
4. Installs remaining tools (opencode, Ogham, Graphify, RTK, codebase-index, Obsidian MCP) — post-docker phase
5. Installs the global `telamon` CLI (symlink at `~/.local/bin/telamon`) and a desktop menu entry

If `.ai/telamon/telamon.ini` exists with `project_name` set, the installer reads it silently (no prompts). If `.env` already has `POSTGRES_PASSWORD` set, the password prompt is also skipped.

### What project init does

`telamon init` wires up a project with all Telamon tools:

- Creates the Obsidian vault at `storage/obsidian/<project-name>/` with `bootstrap/`, `brain/`, `work/`, `reference/`, and `thinking/` folders
- Symlinks agent skills into `<project>/.opencode/skills/telamon`
- Writes `<project>/.ai/telamon/telamon.ini` with the project name
- Installs the Graphify git hook and OpenCode plugin
- Installs the session-capture OpenCode plugin (auto-captures before compaction)
- Registers QMD vault collections and builds the initial semantic index

### What the agent does at session start

Via the `telamon.recall_memories` skill, the agent automatically:

- Activates the project's Ogham memory profile
- Searches for relevant past context (decisions, patterns, bugs)
- Receives Graphify god nodes, communities, and surprising connections (injected by the opencode plugin)
- Receives a git change summary since the last session (injected by the diff-context plugin)
- Builds the codebase index if missing
- Refreshes the QMD vault index

### What the agent does during work

The agent uses Telamon tools transparently:

- Searches Ogham before repeating known work
- Searches the codebase semantically via codebase-index
- Queries Graphify for architectural context (god nodes, communities, relationships)
- Reads `brain/` notes to stay aligned with project decisions and patterns

### How knowledge is saved

The agent saves to **both** Ogham (fast semantic recall) and Obsidian `brain/` (human-readable, curated):

| Event | Ogham | Obsidian |
|---|---|---|
| Non-trivial bug fixed | Stored as a bug memory | Appended to `brain/gotchas.md` |
| Architectural decision | Stored as a decision memory | Appended to `brain/key_decisions.md` |
| Pattern established | Stored as a pattern memory | Appended to `brain/patterns.md` |
| Session ends | Stored as a session summary | Work notes archived from `active/` to `archive/` |

The **session-capture plugin** handles this automatically before every compaction. On explicit wrap-up it also presents a summary of what was saved.

### Recovering memories from past sessions

If you started using Telamon before the session-capture plugin existed, or if memories were lost, you can backfill them from your entire opencode session history:

```bash
telamon recover-memories                 # incremental — current project
telamon recover-memories ~/my-project    # incremental — specific project
telamon recover-memories --all           # incremental — all initialized projects
telamon recover-memories --full          # full reset — clear existing, reprocess all
telamon recover-memories --dry-run       # preview without making changes
telamon recover-memories --batch-size 10 # larger batches (default: 5)
```

This reads the opencode SQLite database (`~/.local/share/opencode/opencode.db`), reconstructs session transcripts, and sends them in batches to an LLM for extraction. Extracted decisions, patterns, gotchas, and lessons are written to both Ogham and the `brain/` markdown files — the same destinations the session-capture plugin uses.

**Recommended first run:** use `--full` to get a clean, deduplicated baseline. Subsequent runs are incremental — only sessions not yet processed are analyzed.

See [Commands → recover-memories](make-targets.md#recover-memories) for all flags and options.
