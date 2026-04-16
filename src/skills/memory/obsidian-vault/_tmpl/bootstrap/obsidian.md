## Obsidian — Curated Knowledge Vault

Obsidian holds the project's curated knowledge: architectural decisions, patterns, gotchas, and in-progress work notes. It is the source of truth for long-lived human-readable knowledge.

### Every session start:
Read `.ai/telamon/memory/brain/memories.md` — this is the index of all knowledge topics for this project.

### Vault structure (per project):
```
.ai/telamon/memory/
  brain/
    memories.md        ← knowledge index — READ THIS FIRST
    key_decisions.md   ← architectural decisions + human stakeholder answers
    patterns.md        ← established codebase patterns
    gotchas.md         ← known traps and constraints
  work/
    active/            ← in-progress notes (1-3 files max)
    archive/YYYY/      ← completed notes by year
    incidents/         ← incident docs
  reference/           ← architecture maps, flow docs, codebase knowledge
  thinking/            ← scratchpad (delete after promoting to notes)
```

### Save to brain/ when you:
- Make an architectural decision → append to `.ai/telamon/memory/brain/key_decisions.md`
- Human stakeholder answers a project question → append to `.ai/telamon/memory/brain/key_decisions.md`
- Establish a codebase pattern → append to `.ai/telamon/memory/brain/patterns.md`
- Find a trap or constraint → append to `.ai/telamon/memory/brain/gotchas.md`

### Retrieval rules:
- **brain/ files**: read directly — always relevant, no search needed
- **All other vault files**: search before read; scope to project subfolder; discard results with score < 0.6
- Max 3 non-brain notes per task

### Wrap-up (on "wrap up" / "wrapping up"):
1. Promote session learnings to the appropriate `brain/` note
2. Archive completed `work/active/` notes → `work/archive/YYYY/`
3. Run `ogham hooks inscribe`
4. Verify every new vault note has at least one `[[wikilink]]`
5. Tell the user what was promoted and saved
