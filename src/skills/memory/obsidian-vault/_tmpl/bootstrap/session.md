## Session Rules — Memory & Knowledge Stack

### Every session start (mandatory, do this first):
1. Switch Ogham profile via `ogham switch_profile` (or the `ogham use` CLI): `ogham use <project-name>`
2. Search Ogham via `ogham hybrid_search` (or the `ogham search` CLI) — recall past context: `ogham search "<current task or recent topic>"`
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
| Specs, ADRs, requirements | Obsidian vault search (follow obsidian-vault skill) |

### Switching projects:
Switch Ogham profile via `ogham switch_profile` (or the `ogham use` CLI):
```
ogham use <new-project-name>
```
Search Ogham via `ogham hybrid_search` (or the `ogham search` CLI) — recall past context:
```
ogham search "<current task or recent topic>"
```
Then read `.ai/telamon/memory/brain/memories.md` and run the self-initialize checks above.
