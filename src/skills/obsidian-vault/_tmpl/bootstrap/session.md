## Session Rules — Memory & Knowledge Stack

### Every session start (mandatory, do this first):
1. `ogham use <project-name>`
2. `ogham hooks recall`
3. Read `<project>/brain/NorthStar.md` from the Obsidian vault

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
| Goals, focus, off-limits | Read `brain/NorthStar.md` directly |
| Architectural decisions + rationale | Read `brain/KeyDecisions.md` directly |
| Codebase patterns | Read `brain/Patterns.md` directly |
| Known traps and constraints | Read `brain/Gotchas.md` directly |
| Architecture, relationships, god nodes | `graphify query "<question>"` |
| Code by meaning ("find auth logic") | codebase-index (ask naturally) |
| Past decisions/bugs this project | `ogham search "<keywords>"` |
| Past session conversations | `cass search "<topic>"` |
| Specs, ADRs, requirements | Obsidian vault search (follow obsidian-vault skill) |

### Switching projects:
```
ogham use <new-project-name>
ogham hooks recall
```
Then read `<new-project>/brain/NorthStar.md` and run the self-initialize checks above.
