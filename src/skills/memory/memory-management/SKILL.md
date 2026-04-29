---
name: telamon.memory_management
description: "Canonical rules for the .ai/telamon/memory/ vault: folder structure, routing, retrieval, writing constraints, entry format, thinking/ lifecycle, pruning, brain note quality, wrap-up. Use when deciding where to save knowledge, formatting entries, or auditing vault structure."
---

# Memory Management — Vault Structure & Rules

Canonical reference for all `.ai/telamon/memory/` vault operations. Other memory skills reference this skill for structure, routing, and quality rules. For Obsidian MCP tool usage (search, read, write, link), load the `telamon.obsidian` skill.

## When to Apply

- Deciding where to save a piece of knowledge
- Formatting memory entries
- Auditing vault structure or brain note quality
- When another memory skill references vault rules

## 1. Vault Structure

```
.ai/telamon/memory/
  bootstrap/                 <- always-on context (loaded like AGENTS.md)
  brain/
    memories.md              <- categorized lessons learned (M-XXX-NNN format)
    key_decisions.md         <- architectural + product decisions, stakeholder answers
    patterns.md              <- established codebase patterns
    gotchas.md               <- known traps and constraints
  work/
    active/                  <- in-progress work notes (3 issues max)
    archive/YYYY/MM/DD       <- completed work notes by year/month/day
    incidents/               <- incident docs
  reference/                 <- architecture maps, flow docs, codebase knowledge
  thinking/                  <- scratchpad for drafts (promote or delete)
```

## 2. Routing Table

| Content                                        | Destination                                           |
|------------------------------------------------|-------------------------------------------------------|
| Agent bootstrap instructions (always-on)       | `bootstrap/`                                          |
| Architectural or product decision + rationale  | `brain/key_decisions.md`                              |
| Human stakeholder answer to a project question | `brain/key_decisions.md`                              |
| New rule from stakeholder                      | `brain/key_decisions.md`                              |
| Established codebase pattern                   | `brain/patterns.md`                                   |
| Trap, constraint, or recurring bug             | `brain/gotchas.md`                                    |
| Categorized lesson learned                     | `brain/memories.md` (M-XXX-NNN format, see section 6) |
| In-progress work note                          | `work/active/`                                        |
| Completed work note                            | `work/archive/YYYY/`                                  |
| Incident doc                                   | `work/incidents/YYYY-MM-DD-<slug>.md`                 |
| Architecture map or flow doc                   | `reference/`                                          |
| Draft or reasoning scratchpad                  | `thinking/` (promote or delete, see section 7)        |
| Partial-progress checkpoint                    | `thinking/YYYY-MM-DD-HH:MM:SS-<task>-partial.md`      |

**Routing rules:**
- Append -- never replace existing content
- One entry per insight
- Include dates in entries

## 3. Retrieval Rules

- bootstrap/ loads automatically at session start -- do not re-read
- brain/ files are small and always relevant -- read directly, no search needed:
  - `brain/key_decisions.md` -- read before architecture work or stakeholder answer lookup
  - `brain/patterns.md` -- read before writing new code
  - `brain/gotchas.md` -- read before touching known problem areas
  - `brain/memories.md` -- search via QMD when you need past lessons; do NOT read at session start
- All other files: search before read; max 3 non-brain notes per task; discard results with relevance score < 0.6
- For search and read tool usage, load the `telamon.obsidian` skill

## 4. Writing Constraints

- Every note must link to at least one existing note via `[[wikilink]]` -- an orphan note is a bug
- Never write: secrets, API keys, passwords
- Never write: files in the vault root (only subfolders)
- Never write: agent instructions outside `bootstrap/` expecting auto-load
- For note creation and update tool usage, load the `telamon.obsidian` skill

## 5. Brain Note Quality Criteria

| File               | Good entry has                                  |
|--------------------|-------------------------------------------------|
| `key_decisions.md` | Decision + rationale (not just the decision)    |
| `patterns.md`      | Actionable, specific pattern with when to apply |
| `gotchas.md`       | Reproducible problem + fix or workaround        |
| `memories.md`      | M-XXX-NNN format per section 6                  |

## 6. Memory Entry Format (memories.md)

### Entry template

```markdown
### M-<CATEGORY>-NNN: <title>
- **Date**: YYYY-MM-DD
- **Context**: What triggered this lesson.
- **Lesson**: The reusable takeaway.
- **Scope**: Where this applies (component, layer, or project-wide).
- **Status**: ACTIVE
```

### Categories

| Category               | Prefix     | Example                                      |
|------------------------|------------|----------------------------------------------|
| Architecture Decisions | `M-ARCH`   | Layer boundaries, dependency rules           |
| Testing Patterns       | `M-TEST`   | Test structure, tooling, strategies          |
| Domain Knowledge       | `M-DOMAIN` | Business rules, domain semantics             |
| Anti-Patterns          | `M-ANTI`   | Approaches that failed -- what to do instead |
| Workflow Lessons       | `M-FLOW`   | Agent delegation, communication, tooling     |

Number sequentially within each category. Check existing entries first.

### Entry quality rules
- **Specific, not generic** -- "Always pass `--no-interaction` to Artisan" not "Be careful with CLI commands"
- **Include context** -- future agents need to understand *why*
- **Scope it** -- a lesson about the Invoice component must say so

### Pruning (when memories.md exceeds 100 entries)
- Mark entries as `SUPERSEDED by M-XXX-NNN` when a newer entry replaces them
- Keep superseded entries for one more session before removing
- Review entries older than 6 months for continued relevance
- Only the orchestrator or human stakeholder may remove entries

## 7. Thinking/ Lifecycle

### Promote or discard
For each file in `thinking/`:
- Contains a reusable lesson -> promote to brain/, then **delete**
- Completed work -> **delete**
- Still live WIP -> keep; rename to `partial-<task>-YYYY-MM-DD.md` if not descriptive

### Hygiene
- Flag any `thinking/` file older than 7 days for user review
- Partial-progress notes use: `YYYY-MM-DD-HH:MM:SS-<task>-partial.md`

### Watermark
Session capture tracks progress via `.ai/telamon/memory/thinking/.last-capture-<worktree-dirname>.json`. Only content after the watermark timestamp needs processing.

## 8. Wrap-Up (on "wrap up" / "wrapping up")

1. Promote session learnings to the appropriate `brain/` note
2. Archive completed `work/active/` notes -> `work/archive/YYYY/`
3. Verify every new vault note has at least one `[[wikilink]]`
4. Tell the user what was promoted and saved

## 9. Memory Tiers (reference)

| Tier      | Store                       | Content                                                      | Writer                               |
|-----------|-----------------------------|--------------------------------------------------------------|--------------------------------------|
| Working   | AGENTS.md + session context | Active goals, current task state                             | Human + agent at session start       |
| Long-term | brain/ notes                | Architectural decisions, domain knowledge, patterns, gotchas | Agent at wrap-up, human for strategy |
