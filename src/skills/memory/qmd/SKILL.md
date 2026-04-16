---
name: telamon.qmd
description: "Semantic search over the project's Obsidian vault using QMD. Use PROACTIVELY before reading vault files directly, before creating new notes (duplicate check), and after completing significant work (find related notes). Trigger: past decisions, past incidents, people, projects, patterns, 'did we ever', 'what do we know about', 'find notes on', session start, wrap-up."
---

# QMD — Vault Semantic Search

QMD provides semantic (vector) search over Telamon Obsidian vault. It runs fully
locally using GGUF models and stores its index at `<telamon-root>/storage/qmd/index.sqlite`.

## Vault collection names

Collections are registered per vault section, prefixed with the project name.
Read the project name from `.ai/telamon/telamon.ini` or use `$(basename $(pwd))`.

| Collection | Contents |
|---|---|
| `<project>-brain` | memories, key decisions, patterns, gotchas |
| `<project>-work` | active tasks, archived work, incidents |
| `<project>-reference` | architecture maps, flow docs, reference |
| `<project>-thinking` | scratchpad drafts, exploratory notes |

Replace `<project>` with the actual project name (e.g. `myapp-brain`).

**Index location:** `<telamon-root>/storage/qmd/index.sqlite` (not `~/.cache/qmd/`).
The Telamon sets `XDG_CACHE_HOME` automatically in all contexts:
- MCP server (`qmd mcp`): set via `opencode.jsonc` environment
- Telamon scripts (`make init`, `make update`): set inline
- Interactive terminal: `qmd()` wrapper function installed by `make up`

You do not need to set `XDG_CACHE_HOME` manually.

---

## When to use QMD

Use QMD **before** reading vault files directly:
- Searching for past decisions, incidents, bugs, or patterns
- Checking for duplicate notes before creating a new one
- Finding notes related to what you just wrote or decided
- Answering "did we ever…" / "what do we know about…" questions
- Session start: check for relevant context before diving in

Use direct file reads **only** when you know the exact note path.

---

## Commands

### Semantic query (best for "what do we know about X")
```bash
qmd query "<natural language question>" -n 10
qmd query "<question>" --json -n 10          # structured output
```

### Keyword search (best for "find notes containing X")
```bash
qmd search "<keywords>"
qmd vsearch "<keywords>"                      # verbose — shows scores
```

### Retrieve a specific note by URI
```bash
qmd get "qmd://<project>-brain/brain/key_decisions.md"
qmd multi-get "qmd://..." "qmd://..."
```

### Check index status
```bash
qmd status
```

### Keep index current
```bash
qmd update          # scan collections for new/changed files
qmd embed           # embed any queued files
```

---

## Usage patterns

### 1 — Session start (fast context bootstrap)
```bash
# Run incremental update first (fast after initial build)
qmd update && qmd embed

# Then query for recent relevant context
qmd query "what was the last major decision we made" -n 5
qmd query "what patterns and gotchas should I know" -n 5
```

### 2 — Before reading a brain file
```bash
# Instead of: cat .ai/telamon/memory/brain/key_decisions.md
qmd query "key decisions and architectural choices" -n 8
```

### 3 — Before creating a new note
```bash
# Check for duplicates
qmd query "<proposed note title or summary>" -n 3
# If results overlap with your intended note, update the existing note instead
```

### 4 — After completing significant work
```bash
qmd query "<what you just built or decided>" -n 5
# Review related notes — update them if your work changes what they say
```

### 5 — Incident investigation
```bash
qmd query "errors similar to <error message>" -n 5
qmd query "previous incidents with <component>" -n 5
```

---

## Tips

- **Query width**: use a full sentence, not just keywords — QMD is semantic
- **Collection scope**: query a specific collection to reduce noise:
  `qmd query "..." -n 10` searches all collections;  
  use `qmd get "qmd://<project>-brain/..."` to target brain notes
- **After `qmd update`**: always run `qmd embed` — update enqueues, embed processes
- **First run**: models download automatically (~2 GB); subsequent runs are fast
- **MCP alternative**: the QMD MCP server (`qmd mcp`) exposes `query`, `get`,
  `multi_get`, and `status` — the same commands, accessible as MCP tools

---

## Quick reference

| Task | Command |
|---|---|
| Semantic question | `qmd query "<question>" -n 10` |
| Keyword search | `qmd search "<terms>"` |
| Get specific note | `qmd get "qmd://<collection>/path/to/note.md"` |
| Incremental update | `qmd update && qmd embed` |
| Check status | `qmd status` |
