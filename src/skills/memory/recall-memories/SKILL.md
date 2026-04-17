---
name: telamon.recall_memories
description: "Recall context at session start. Switch Ogham profile, search past work, read brain/ notes, update vault index, initialize knowledge tools. Use at the beginning of every session."
---

# Recall Memories

Run at the beginning of every session, regardless of workflow. Even standalone tasks must start here.

## 1. Switch memory profile

```
ogham use <project-name>
```

## 2. Recall past context

Search Ogham for relevant prior work:
```
ogham search "<current task or recent topic>"
```

Read brain/ notes directly:
- `.ai/telamon/memory/brain/key_decisions.md` — architectural and product decisions
- `.ai/telamon/memory/brain/patterns.md` — established patterns and best practices
- `.ai/telamon/memory/brain/gotchas.md` — known traps and constraints
- `.ai/telamon/memory/brain/memories.md` — categorized lessons learned

## 3. Update vault index

```bash
qmd update && qmd embed
qmd query "what was the last major decision we made" -n 5
qmd query "what patterns and gotchas should I know" -n 5
```

## 4. Self-initialize (check each time, build if missing)

**Graphify knowledge graph:**
- Check: does `graphify-out/GRAPH_REPORT.md` exist?
- If NO: run `graphify .` — one-time build
- If YES: read `graphify-out/GRAPH_REPORT.md` before touching architecture

**Semantic codebase index:**
- Check: does `.opencode/codebase-index/` exist?
- If NO: call `index_codebase` tool — one-time build
- If YES: index is ready

**cass session history:**
- Load the `cass` skill for full usage guide
- **Always use `--robot`** — bare `cass search` launches a TUI and blocks the session
- Search: `cass search "<topic>" --robot --workspace "$(pwd)" --limit 5`

## 5. Retrieval priority

When you need information, use the right tool for the question type:

| Question type | Tool |
|---|---|
| Lessons learned (categorized) | Read `brain/memories.md` directly |
| Architectural decisions + stakeholder answers | Read `brain/key_decisions.md` directly |
| Codebase patterns | Read `brain/patterns.md` directly |
| Known traps and constraints | Read `brain/gotchas.md` directly |
| Vault semantic search ("did we ever...") | `qmd query "<question>" -n 10` |
| Architecture, relationships, god nodes | `graphify query "<question>"` |
| Relational/temporal queries ("what depends on X?") | Graphiti MCP (only when `telamon-graphiti` container is running) |
| Code by meaning ("find auth logic") | codebase-index (ask naturally) |
| Past decisions/bugs this project | `ogham search "<keywords>"` |
| Past session conversations | `cass search "<topic>" --robot --workspace "$(pwd)"` |
| Specs, ADRs, requirements | Obsidian vault search (follow `obsidian-vault` skill) |

## Switching projects

```
ogham use <new-project-name>
```

Then re-run steps 2–4 for the new project context.
