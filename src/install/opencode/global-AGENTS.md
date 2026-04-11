## Memory & Knowledge — Session Rules

### Tools available:
- **Ogham** — semantic memory (decisions, bugs, patterns across sessions)
- **codebase-index** — semantic code search for this project
- **Obsidian MCP** — curated knowledge vault (brain/, work/, reference/)
- **Graphify** — knowledge graph (auto-built on first session)
- **cass** — search past agent session history

### On EVERY session start — do this first:
1. `ogham use <project-folder-name>`
2. `ogham hooks recall`
3. Read `<project>/brain/NorthStar.md` from the Obsidian vault
4. Check project AGENTS.md for self-initialization instructions

### Obsidian vault brain/ structure (per project):
- `brain/NorthStar.md` — current goals and focus — read at session start
- `brain/KeyDecisions.md` — architectural decisions with rationale
- `brain/Patterns.md` — established patterns in this codebase
- `brain/Gotchas.md` — known traps and constraints
- `work/active/` — in-progress work notes
- `reference/` — architecture maps and codebase docs
- `thinking/` — scratchpad (delete after promoting to notes)

### Self-initialization (once per project, then automatic):
- If `graphify-out/GRAPH_REPORT.md` missing → run `graphify .` then read it
- If `.opencode/codebase-index/` missing → run `/index` to build it

### Save to Ogham AND Obsidian brain/ when you:
- Fix a non-trivial bug: `ogham store "bug: <desc>"` + add to `brain/Gotchas.md` if recurring
- Make an architectural decision: `ogham store "decision: ..."` + add to `brain/KeyDecisions.md`
- Establish a pattern: `ogham store "pattern: ..."` + add to `brain/Patterns.md`
- Finish significant work: `ogham hooks inscribe`

### Wrap-up (when user says "wrap up" or "wrapping up"):
Follow the obsidian-vault skill wrap-up workflow:
1. Promote learnings to brain/ notes
2. Archive completed work/active/ notes
3. Run `ogham hooks inscribe`
4. Verify new notes have wikilinks

### Never save: routine commands, secrets, trivial edits

### Codebase search priority:
1. `brain/` files (direct read) — decisions, patterns, gotchas
2. Graphify graph — `graphify query "<question>"`
3. codebase-index — semantic code search (ask naturally)
4. `ogham search "<keywords>"` — past session decisions/bugs
5. `cass search "<topic>"` — past session conversations
6. Obsidian vault search — specs, docs (follow obsidian-vault skill)
