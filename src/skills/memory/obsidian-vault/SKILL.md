---
name: obsidian-vault
description: "Use when reading, searching, or writing the Obsidian vault via obsidian MCP tools. Triggers: 'check the docs', 'look at my notes', 'update the wiki', referencing specs, ADRs, decisions, patterns or gotchas. Also triggers on 'wrap up', 'end session', 'wrapping up'. Always follow the vault structure and retrieval rules — never browse blindly."
---

# Obsidian Vault — Structure & Usage Rules

## Vault folder structure (per project)

Each project's vault lives at `.ai/telamon/memory/` inside the project. Inside:

```
.ai/telamon/memory/
  bootstrap/                 ← always loaded into context (treat as part of AGENTS.md)
  brain/
    memories.md              ← knowledge index — READ THIS FIRST
    key_decisions.md         ← architectural decisions + human stakeholder answers
    patterns.md              ← established patterns in this codebase
    gotchas.md               ← known traps and constraints
  work/
    active/                  ← current in-progress work notes (1-3 files max)
    archive/YYYY-MM-DD/      ← completed work notes by year-month-day
    incidents/               ← incident docs
  reference/                 ← architecture maps, flow docs, codebase knowledge
  thinking/                  ← scratchpad for drafts (delete after promoting to notes)
```

## Retrieval rules

### Rule 0 — bootstrap/ is always in context
Files in `bootstrap/` are loaded automatically at session start (equivalent to being written
directly in AGENTS.md). Do not search for or re-read them — their content is already present.
Never write agent instructions to any other folder expecting them to be auto-loaded.

### Rule 1 — Search before read
Never call read_note or list_files without searching first.
```
✔  search_vault("auth migration", path="my-project/")
✖  list_files("/")
✖  read_note("index.md")  ← never speculative
```
Exception: the user explicitly names a file, or you're reading brain/ files at session start.

### Rule 2 — Direct reads for brain/ files
brain/ files are small and always relevant — read them directly, no search needed:
- `.ai/telamon/memory/brain/memories.md` — read at session start
- `.ai/telamon/memory/brain/key_decisions.md` — read before architecture work or when stakeholder answers are needed
- `.ai/telamon/memory/brain/patterns.md` — read before writing new code
- `.ai/telamon/memory/brain/gotchas.md` — read before touching known problem areas

### Rule 3 — Max 3 notes per task (non-brain)
Pick top 3 by relevance score. Tell the user if truncated ("Found 7 notes, reading top 3").

### Rule 4 — Scope searches to project subfolder
```
✔  search_vault("auth migration", path="my-project/")
✖  search_vault("auth migration")  ← entire vault, may pull unrelated projects
```

### Rule 5 — Score threshold
Discard results with relevance score < 0.6. Say "No relevant notes found" and use Ogham instead.

## Writing rules

### Creating notes
1. Use YAML frontmatter: `date`, `description` (~150 chars), `tags`, `status`, `project`
2. Place files in the correct subfolder (see structure above)
3. Every new note must link to at least one existing note via `[[wikilink]]`
4. A note without links is a bug — add links before finishing

### Updating existing notes
- Use patch_note (not write_note) to preserve frontmatter
- Add `updated: <date>` to frontmatter
- Keep the same heading structure

### Where to write things
| Content                                          | Location                                                |
|--------------------------------------------------|---------------------------------------------------------|
| Agent bootstrap instructions (always-on context) | `.ai/telamon/memory/bootstrap/`                         |
| Architectural decision + rationale               | `.ai/telamon/memory/brain/key_decisions.md`             |
| Product decision + rationale                     | `.ai/telamon/memory/brain/key_decisions.md`             |
| Human stakeholder answer to a project question   | `.ai/telamon/memory/brain/key_decisions.md`             |
| Codebase pattern established                     | `.ai/telamon/memory/brain/patterns.md`                  |
| Hidden trap or constraint found                  | `.ai/telamon/memory/brain/gotchas.md`                   |
| In-progress work note                            | `.ai/telamon/memory/work/active/`                       |
| Completed work note                              | `.ai/telamon/memory/work/archive/YYYY-MM-DD/`           |
| Incident                                         | `.ai/telamon/memory/work/incidents/`                    |
| Architecture doc                                 | `.ai/telamon/memory/reference/`                         |
| Draft / reasoning scratchpad                     | `.ai/telamon/memory/thinking/` (delete after promoting) |

### Never write:
- Secrets, API keys, passwords
- Content that duplicates what's already in Ogham (no need to store the same thing twice)
- Files in the vault root (only project subfolders)
- Agent instructions outside `bootstrap/` expecting them to be auto-loaded

## Wrap-up workflow

When the user says "wrap up", "let's wrap", "wrapping up", or similar — follow the `telamon.remember_session` skill.
