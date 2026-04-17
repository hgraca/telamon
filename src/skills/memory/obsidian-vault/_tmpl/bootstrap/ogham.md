## Ogham — Semantic Agent Memory

Ogham stores and retrieves decisions, bugs, and patterns across sessions using semantic search backed by a local Postgres + pgvector database and Ollama embeddings.

### Every session (mandatory, do this first):
Switch Ogham profile via `ogham switch_profile` (or the `ogham use` CLI):
```
ogham use <project-name>
```
Search Ogham via `ogham hybrid_search` (or the `ogham search` CLI) — recall past context:
```
ogham search "<current task or recent topic>"
```

### Save to Ogham AND Obsidian brain/ when you:
- Fix a non-trivial bug: `ogham store "bug: <desc>"` + add to `.ai/telamon/memory/brain/gotchas.md` if recurring
- Make an architectural decision: `ogham store "decision: X over Y because Z"` + add to `.ai/telamon/memory/brain/key_decisions.md`
- Human stakeholder answers a project question: record in `.ai/telamon/memory/brain/key_decisions.md`
- Establish a pattern: `ogham store "pattern: <desc>"` + add to `.ai/telamon/memory/brain/patterns.md`
- Finish significant work: Save to Ogham via `ogham store_memory` (or the `ogham store` CLI) — capture significant decisions, patterns, and bugs

### Retrieve:
- `ogham search "<keywords>"` — past decisions, bugs, patterns for this project

### Never save: routine commands (ls/git status/cat), secrets, trivial single-line edits
