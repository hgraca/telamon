<!-- ogham-managed -->
# PROJECT_NAME

<!-- Add your stack, conventions, build commands, contacts here -->

---

## Memory & Tooling Setup

### Step 1 — Every session (mandatory, do this first):
```
ogham use OGHAM_PROFILE
ogham hooks recall
```
Then read `PROJECT_NAME/brain/NorthStar.md` from the Obsidian vault if it exists.

### Step 2 — Self-initialize tools if not yet built:

**Knowledge graph (Graphify):**
- If `graphify-out/GRAPH_REPORT.md` missing → run `graphify .` (once, git hooks maintain it)
- If exists → read it before touching any architecture

**Semantic codebase index:**
- If `.opencode/codebase-index/` missing → run `index_codebase` tool (once, file watcher maintains it)

**Session history (cass):**
- Run `cass index` once on this machine to index past sessions

### Step 3 — Retrieval priority:
1. Obsidian `brain/` files (direct read) — decisions, patterns, gotchas
2. `graphify query "<question>"` — architecture, relationships
3. Codebase-index — semantic code search (ask in plain English)
4. `ogham search "<keywords>"` — past session decisions/bugs
5. `cass search "<topic>"` — past session conversations
6. Obsidian vault search — specs, docs (follow obsidian-vault skill)

### Step 4 — Save during the session (BOTH Ogham AND Obsidian brain/):
- Non-trivial bug: `ogham store "bug: <desc>"` + add to `brain/Gotchas.md` if recurring
- Decision: `ogham store "decision: X over Y because Z"` + add to `brain/KeyDecisions.md`
- Pattern: `ogham store "pattern: <desc>"` + add to `brain/Patterns.md`
- End of significant work: `ogham hooks inscribe`

### Step 5 — Wrap-up (when user says "wrap up" or "wrapping up"):
1. Promote session learnings → appropriate `brain/` note
2. Archive completed `work/active/` notes → `work/archive/YYYY/`
3. Run `ogham hooks inscribe`
4. Verify every new vault note has at least one `[[wikilink]]`
5. Tell the user what was promoted and saved

### Never save: routine commands (ls/git status/cat), secrets, trivial single-line edits

### Obsidian vault structure for this project:
```
PROJECT_NAME/
  brain/
    NorthStar.md      ← goals, current focus, off-limits areas
    KeyDecisions.md   ← architectural decisions + rationale
    Patterns.md        ← established codebase patterns
    Gotchas.md         ← known traps and constraints
  work/
    active/            ← in-progress notes
    archive/YYYY/      ← completed notes by year
    incidents/         ← incident docs
  reference/           ← architecture maps, flow docs
  thinking/            ← scratchpad (delete after promoting)
```
