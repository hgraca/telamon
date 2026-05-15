---
name: telamon.remember_task
description: "Record what was learned after completing task. Review discoveries, update brain/ notes with structured lessons. Use after finishing task, fixing non-trivial bug, or completing planning round."
---

# Remember Task

Run after finishing task, fixing non-trivial bug, completing planning round, or delivering any meaningful output — whether part of formal workflow or standalone.

## 0. Commit check (mandatory)

Before recording lessons, verify all file changes committed. Run `git status` — if uncommitted changes exist, stage specific files (`git add <files>`, never `git add -A`), verify with `git diff --staged --stat`, and commit with descriptive message. Do not proceed to step 1 until working tree is clean.

## 1. Review what was learned

Ask yourself:
- Did I discover reusable pattern?
- Did I hit trap or constraint others should know?
- Was decision made (or clarified) during this work?
- Did human stakeholder provide new context?

## 2. Route to correct brain file

- **Traps, constraints, or recurring bugs** → use `telamon.remember_gotcha` skill (writes to `brain/gotchas/`)
- **All other lessons** → append to `.ai/telamon/memory/brain/memories/` using M-XXX-NNN entry format from `telamon.memory_management` skill (section 6)

One entry per lesson -- do not bundle multiple takeaways.

## 3. Pruning

When memories.md exceeds 100 entries, follow pruning rules in `telamon.memory_management` skill (section 6).