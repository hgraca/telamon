## Obsidian — Curated Knowledge Vault

Obsidian holds the project's curated knowledge: goals, architectural decisions, patterns, gotchas, and in-progress work notes. It is the source of truth for long-lived human-readable knowledge.

### Every session start:
Read `<project>/brain/NorthStar.md` from the vault — this sets goals, focus, and off-limits areas.

### Vault structure (per project):
```
<project>/
  brain/
    NorthStar.md       ← current goals, focus, off-limits — READ THIS FIRST
    KeyDecisions.md   ← architectural decisions with rationale
    Patterns.md        ← established codebase patterns
    Gotchas.md         ← known traps and constraints
  work/
    active/            ← in-progress notes (1-3 files max)
    archive/YYYY/      ← completed notes by year
    incidents/         ← incident docs
  reference/           ← architecture maps, flow docs, codebase knowledge
  thinking/            ← scratchpad (delete after promoting to notes)
```

### Save to brain/ when you:
- Make an architectural decision → append to `brain/KeyDecisions.md`
- Establish a codebase pattern → append to `brain/Patterns.md`
- Find a trap or constraint → append to `brain/Gotchas.md`
- Goals or focus shift → update `brain/NorthStar.md`

### Retrieval rules:
- **brain/ files**: read directly — always relevant, no search needed
- **All other vault files**: search before read; scope to project subfolder; discard results with score < 0.6
- Max 3 non-brain notes per task

### Wrap-up (on "wrap up" / "wrapping up"):
1. Promote session learnings to the appropriate `brain/` note
2. Archive completed `work/active/` notes → `work/archive/YYYY/`
3. Verify every new vault note has at least one `[[wikilink]]`
