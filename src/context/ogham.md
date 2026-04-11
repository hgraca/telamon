## Ogham — Semantic Agent Memory

Ogham stores and retrieves decisions, bugs, and patterns across sessions using semantic search backed by a local Postgres + pgvector database and Ollama embeddings.

### Every session (mandatory):
```
ogham use <project-name>
ogham hooks recall
```

### Save when you:
- Fix a non-trivial bug: `ogham store "bug: <desc>"`
- Make an architectural decision: `ogham store "decision: X over Y because Z"`
- Establish a pattern: `ogham store "pattern: <desc>"`
- Finish significant work: `ogham hooks inscribe`

### Retrieve:
- `ogham search "<keywords>"` — past decisions, bugs, patterns for this project

### Never save: routine commands (ls/git status/cat), secrets, trivial single-line edits
