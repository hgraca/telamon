## Ogham — Semantic Agent Memory

Ogham stores and retrieves decisions, bugs, and patterns across sessions using semantic search backed by a local Postgres + pgvector database and Ollama embeddings.

### Every session (mandatory, do this first):
```
ogham use <project-name>
ogham hooks recall
```

### Save to Ogham AND Obsidian brain/ when you:
- Fix a non-trivial bug: `ogham store "bug: <desc>"` + add to `.ai/telamon/memory/brain/gotchas.md` if recurring
- Make an architectural decision: `ogham store "decision: X over Y because Z"` + add to `.ai/telamon/memory/brain/key_decisions.md`
- Human stakeholder answers a project question: record in `.ai/telamon/memory/brain/key_decisions.md`
- Establish a pattern: `ogham store "pattern: <desc>"` + add to `.ai/telamon/memory/brain/patterns.md`
- Finish significant work: `ogham hooks inscribe`

### Retrieve:
- `ogham search "<keywords>"` — past decisions, bugs, patterns for this project

### Never save: routine commands (ls/git status/cat), secrets, trivial single-line edits
