---
tags: [bootstrap, session]
description: Session start, vault structure, retrieval priority, wrap-up rules
---

## Session — Memory & Knowledge Stack

### Every session start (mandatory, do this first):
1. Switch Ogham profile: `ogham use <project-name>`
2. Recall past context: `ogham search "<current task or recent topic>"`
3. Read `.ai/telamon/memory/brain/memories.md` — knowledge index for this project

### Self-initialize once per project (check each time, build if missing):

**Knowledge graph (Graphify):**
- If `graphify-out/GRAPH_REPORT.md` missing → run `graphify .` (git hooks maintain it after)
- If exists → read it before touching any architecture

**Semantic codebase index:**
- If `.opencode/codebase-index/` missing → run `index_codebase` tool (file watcher maintains it after)

**Session history (cass):**
- Run `cass index` once on this machine to index past sessions

### Retrieval priority:
| Question type | Tool |
|---|---|
| Knowledge index | Read `.ai/telamon/memory/brain/memories.md` directly |
| Architectural decisions + stakeholder answers | Read `.ai/telamon/memory/brain/key_decisions.md` directly |
| Codebase patterns | Read `.ai/telamon/memory/brain/patterns.md` directly |
| Known traps and constraints | Read `.ai/telamon/memory/brain/gotchas.md` directly |
| Architecture, relationships, god nodes | `graphify query "<question>"` |
| Code by meaning ("find auth logic") | codebase-index (ask naturally) |
| Past decisions/bugs this project | `ogham search "<keywords>"` |
| Past session conversations | `cass search "<topic>"` |
| Specs, ADRs, requirements | Obsidian vault search |

For detailed tool usage, load: `telamon.ogham`, `telamon.cass`, or `telamon.graphify` skill.

### Vault structure:
```
.ai/telamon/memory/
  brain/
    memories.md        ← knowledge index — READ FIRST
    key_decisions.md   ← decisions + stakeholder answers
    patterns.md        ← codebase patterns
    gotchas.md         ← traps and constraints
  work/
    active/            ← in-progress notes (1-3 max)
    archive/YYYY/      ← completed by year
    incidents/         ← incident docs
  reference/           ← architecture maps, flow docs
  thinking/            ← scratchpad (delete after promoting)
```

### Save to brain/ when you:
- Make an architectural decision → append to `.ai/telamon/memory/brain/key_decisions.md`
- Human stakeholder answers a project question → append to `.ai/telamon/memory/brain/key_decisions.md`
- Establish a codebase pattern → append to `.ai/telamon/memory/brain/patterns.md`
- Find a trap or constraint → append to `.ai/telamon/memory/brain/gotchas.md`

### Vault retrieval rules:
- **brain/ files**: read directly — always relevant, no search needed
- **All other vault files**: search before read; scope to project subfolder; discard results with score < 0.6
- Max 3 non-brain notes per task

### Wrap-up (on "wrap up" / "wrapping up"):
1. Promote session learnings to the appropriate `brain/` note
2. Archive completed `work/active/` notes → `work/archive/YYYY/`
3. Save to Ogham via `ogham store_memory` — capture significant decisions, patterns, and bugs
4. Verify every new vault note has at least one `[[wikilink]]`
5. Tell the user what was promoted and saved

### Switching projects:
```
ogham use <new-project-name>
ogham search "<current task or recent topic>"
```
Then read `.ai/telamon/memory/brain/memories.md` and run the self-initialize checks above.

## See also

- [[memories]]
- [[key_decisions]]
- [[patterns]]
- [[gotchas]]
