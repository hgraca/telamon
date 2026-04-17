---
name: telamon.remember_task
description: "Record what was learned after completing a task. Review discoveries, update memories.md with structured lessons, store in Ogham. Use after finishing a task, fixing a non-trivial bug, or completing a planning round."
---

# Remember Task

Run after finishing a task, fixing a non-trivial bug, completing a planning round, or delivering any meaningful output — whether part of a formal workflow or standalone.

## 1. Review what was learned

Ask yourself:
- Did I discover a reusable pattern?
- Did I hit a trap or constraint others should know?
- Was a decision made (or clarified) during this work?
- Did the human stakeholder provide new context?

## 2. Update memories.md

Append new lessons to `.ai/telamon/memory/brain/memories.md` using the format below. One entry per lesson — do not bundle multiple takeaways.

**Entry format:**

```markdown
### M-<CATEGORY>-NNN: <title>
- **Date**: YYYY-MM-DD
- **Context**: What triggered this lesson.
- **Lesson**: The reusable takeaway.
- **Scope**: Where this applies (component, layer, or project-wide).
- **Status**: ACTIVE
```

**Categories and prefixes:**

| Category               | Prefix     | Example                                     |
|------------------------|------------|---------------------------------------------|
| Architecture Decisions | `M-ARCH`   | Layer boundaries, dependency rules          |
| Testing Patterns       | `M-TEST`   | Test structure, tooling, strategies         |
| Domain Knowledge       | `M-DOMAIN` | Business rules, domain semantics            |
| Anti-Patterns          | `M-ANTI`   | Approaches that failed — what to do instead |
| Workflow Lessons       | `M-FLOW`   | Agent delegation, communication, tooling    |

Number sequentially within each category. Check existing entries to find the next number.

**Entry rules:**
- **Specific, not generic** — "Always pass `--no-interaction` to Artisan" is good. "Be careful with CLI commands" is too vague.
- **Include context** — future agents need to understand *why* this lesson exists.
- **Scope it** — a lesson about the Invoice component should say so.

## 3. Store in Ogham

```
ogham store "lesson: <one-line summary of what was learned>"
```

## 4. Pruning (when memories.md exceeds 100 entries)

- Mark entries as `SUPERSEDED by M-XXX-NNN` when a newer entry replaces them.
- Do not delete superseded entries immediately — keep for one more session.
- After one session, superseded entries may be removed.
- Entries older than 6 months: review for continued relevance.
- Only the PO or human stakeholder may remove entries.
