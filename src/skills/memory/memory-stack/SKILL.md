---
name: memory-stack
description: "Use at session start and when deciding what to store or retrieve. Covers Ogham (agent memory), codebase-index (code search), cass (session history), graphify (knowledge graph), QMD (vault semantic search), and Obsidian (docs vault + brain/ notes). Trigger: session start, 'remember this', 'what did we decide', 'search the codebase', 'wrap up', or after completing significant work."
---

# Memory Stack — Session Rules

## Step 1 — Every session (mandatory):
```
ogham use <project-name>
ogham hooks recall
```
Read `.ai/telamon/memory/brain/memories.md` — knowledge index for this project.

Run QMD incremental update to keep vault index current:
```bash
qmd update && qmd embed
```
Then query for recent relevant context:
```bash
qmd query "what was the last major decision we made" -n 5
qmd query "what patterns and gotchas should I know" -n 5
```

## Step 2 — Self-initialize once per project (check each time, build if missing):

**Graphify knowledge graph:**
- Check: does `graphify-out/GRAPH_REPORT.md` exist in the project root?
- If NO: run `graphify .` — builds the graph (one-time, git hooks maintain it after)
- If YES: read `graphify-out/GRAPH_REPORT.md` before touching any architecture

**Semantic codebase index:**
- Check: does `.opencode/codebase-index/` directory exist?
- If NO: call the `index_codebase` tool to build it (one-time, file watcher maintains it)
- If YES: index is ready — semantic code search available

**cass session history:**
- Load the `cass` skill for full usage guide (robot mode, token budgets, filters)
- Run `cass index` once per machine to build the index; updates automatically after that
- **Always use `--robot`** — bare `cass search` launches an interactive TUI and blocks the session
- Search: `cass search "<topic>" --robot --workspace "$(pwd)" --limit 5`

## Step 3 — Retrieval priority:
| Question type | Tool |
|---|---|
| Knowledge index | Read `.ai/telamon/memory/brain/memories.md` directly |
| Architectural decisions + stakeholder answers | Read `.ai/telamon/memory/brain/key_decisions.md` directly |
| Codebase patterns | Read `.ai/telamon/memory/brain/patterns.md` directly |
| Known traps and constraints | Read `.ai/telamon/memory/brain/gotchas.md` directly |
| Vault semantic search ("did we ever…") | `qmd query "<question>" -n 10` (load `telamon.qmd` skill for full guide) |
| Architecture, relationships, god nodes | `graphify query "<question>"` |
| Code by meaning ("find auth logic") | codebase-index (ask naturally) |
| Past decisions/bugs this project | `ogham search "<keywords>"` |
| Past session conversations | `cass search "<topic>" --robot --workspace "$(pwd)"` (load `cass` skill for full guide) |
| Specs, ADRs, requirements | Obsidian vault search (follow obsidian-vault skill) |

## Step 4 — Save to BOTH Ogham AND Obsidian brain/ when:
- Bug fixed (non-trivial): `ogham store "bug: <desc>"` + add to `.ai/telamon/memory/brain/gotchas.md` if recurring
- Decision made: `ogham store "decision: X over Y because Z"` + add to `.ai/telamon/memory/brain/key_decisions.md`
- Human stakeholder answers a project question: record in `.ai/telamon/memory/brain/key_decisions.md`
- Pattern established: `ogham store "pattern: <desc>"` + add to `.ai/telamon/memory/brain/patterns.md`
- Session ends with significant work: `ogham hooks inscribe`

## Never save: ls/git status/cat/pwd, secrets, trivial single-line edits

## Wrap-up (when user says "wrap up", "wrapping up", "let's wrap"):
Follow the session-capture skill (telamon.session-capture):
1. Promote session learnings to brain/ notes (key_decisions, patterns, gotchas)
2. Archive completed work/active/ notes
3. `ogham hooks inscribe`
4. Verify new vault notes have [[wikilinks]]
5. Tell the user what was promoted and saved

## Switching projects:
```
ogham use <new-project-name>
ogham hooks recall
```
Then read `.ai/telamon/memory/brain/memories.md` and run Step 2 checks.
