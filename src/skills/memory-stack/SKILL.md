---
name: memory-stack
description: "Use at session start and when deciding what to store or retrieve. Covers Ogham (agent memory), codebase-index (code search), cass (session history), graphify (knowledge graph), and Obsidian (docs vault + brain/ notes). Trigger: session start, 'remember this', 'what did we decide', 'search the codebase', 'wrap up', or after completing significant work."
---

# Memory Stack — Session Rules

## Step 1 — Every session (mandatory):
```
ogham use <project-name>
ogham hooks recall
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
- Run `cass index` if you haven't yet on this machine
- Adds all past agent sessions to the searchable index

## Step 3 — Retrieval priority:
| Question type | Tool |
|---|---|
| Memory topics / knowledge index | Read `brain/memories.md` directly |
| Architectural decisions + rationale | Read `brain/key_decisions.md` directly |
| Codebase patterns | Read `brain/patterns.md` directly |
| Known traps and constraints | Read `brain/gotchas.md` directly |
| Architecture, relationships, god nodes | `graphify query "<question>"` |
| Code by meaning ("find auth logic") | codebase-index (ask naturally) |
| Past decisions/bugs this project | `ogham search "<keywords>"` |
| Past session conversations | `cass search "<topic>"` |
| Specs, ADRs, requirements | Obsidian vault search (follow obsidian-vault skill) |

## Step 4 — Save to BOTH Ogham AND Obsidian brain/ when:
- Bug fixed (non-trivial): `ogham store "bug: <desc>"` + add to `brain/gotchas.md` if recurring
- Decision made: `ogham store "decision: X over Y because Z"` + add to `brain/key_decisions.md`
- Pattern established: `ogham store "pattern: <desc>"` + add to `brain/patterns.md`
- Session ends with significant work: `ogham hooks inscribe`

## Never save: ls/git status/cat/pwd, secrets, trivial single-line edits

## Wrap-up (when user says "wrap up", "wrapping up", "let's wrap"):
Follow the obsidian-vault skill wrap-up workflow:
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
Then read `<new-project>/brain/memories.md` and run Step 2 checks.
