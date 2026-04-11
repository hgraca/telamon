---
name: obsidian-vault
description: "Use when reading, searching, or writing the Obsidian vault via obsidian MCP tools. Triggers: 'check the docs', 'look at my notes', 'update the wiki', referencing specs, ADRs, decisions, patterns or gotchas. Also triggers on 'wrap up', 'end session', 'wrapping up'. Always follow the vault structure and retrieval rules — never browse blindly."
---

# Obsidian Vault — Structure & Usage Rules

## Vault folder structure (per project)

Each project lives in its own subfolder. Inside:

```
<project>/
  brain/
    NorthStar.md      ← current goals, focus, what's off-limits — READ THIS FIRST
    Memories.md        ← index of memory topics (points to topic notes)
    KeyDecisions.md   ← architectural decisions with rationale
    Patterns.md        ← established patterns in this codebase
    Gotchas.md         ← known traps and constraints
  work/
    active/            ← current in-progress work notes (1-3 files max)
    archive/YYYY/      ← completed work notes by year
    incidents/         ← incident docs
  reference/           ← architecture maps, flow docs, codebase knowledge
  thinking/            ← scratchpad for drafts (delete after promoting to notes)
```

## Retrieval rules

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
- `<project>/brain/NorthStar.md` — read at session start
- `<project>/brain/KeyDecisions.md` — read before architecture work
- `<project>/brain/Patterns.md` — read before writing new code
- `<project>/brain/Gotchas.md` — read before touching known problem areas

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
1. Use YAML frontmatter: `date`, `description` (~150 chars), `tags`, `status`
2. Place files in the correct subfolder (see structure above)
3. Every new note must link to at least one existing note via `[[wikilink]]`
4. A note without links is a bug — add links before finishing

### Updating existing notes
- Use patch_note (not write_note) to preserve frontmatter
- Add `updated: <date>` to frontmatter
- Keep the same heading structure

### Where to write things
| Content | Location |
|---|---|
| Architectural decision + rationale | `brain/KeyDecisions.md` |
| Codebase pattern established | `brain/Patterns.md` |
| Hidden trap or constraint found | `brain/Gotchas.md` |
| Current goals / focus shift | `brain/NorthStar.md` |
| In-progress work note | `work/active/` |
| Completed work note | `work/archive/YYYY/` |
| Incident | `work/incidents/` |
| Architecture doc | `reference/` |
| Draft / reasoning scratchpad | `thinking/` (delete after promoting) |

### Never write:
- Secrets, API keys, passwords
- Content that duplicates what's already in Ogham (no need to store the same thing twice)
- Files in the vault root (only project subfolders)

## Wrap-up workflow

When the user says "wrap up", "let's wrap", "wrapping up", or similar — run this before ending:

1. **Promote learnings to brain/**:
   - New architectural decision → append to `brain/KeyDecisions.md`
   - New codebase pattern → append to `brain/Patterns.md`
   - New gotcha or constraint → append to `brain/Gotchas.md`
   - Goals shifted → update `brain/NorthStar.md`

2. **Archive completed work**:
   - Move completed `work/active/` notes to `work/archive/YYYY/`

3. **Save to Ogham**:
   - Run `ogham hooks inscribe` to capture session activity
   - Explicitly store any decisions or bugs not yet saved

4. **Verify links**:
   - Check that new notes have at least one inbound wikilink
   - Orphan notes (no links) should be linked or deleted

Tell the user what was promoted and what was saved before ending the session.
