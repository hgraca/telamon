---
name: telamon.remember_task
description: "Record what was learned after completing a task. Review discoveries, update brain/ notes with structured lessons. Use after finishing a task, fixing a non-trivial bug, or completing a planning round."
---

# Remember Task

Run after finishing a task, fixing a non-trivial bug, completing a planning round, or delivering any meaningful output — whether part of a formal workflow or standalone.

## 0. Commit check (mandatory)

Before recording lessons, verify all file changes are committed. Run `git status` — if uncommitted changes exist, stage specific files (`git add <files>`, never `git add -A`), verify with `git diff --staged --stat`, and commit with a descriptive message. Do not proceed to step 1 until the working tree is clean.

## 1. Review what was learned

Ask yourself:
- Did I discover a reusable pattern?
- Did I hit a trap or constraint others should know?
- Was a decision made (or clarified) during this work?
- Did the human stakeholder provide new context?

## 2. Route to the correct brain file

- **Traps, constraints, or recurring bugs** → use the `telamon.remember_gotcha` skill (writes to `brain/gotchas.md`)
- **All other lessons** → append to `.ai/telamon/memory/brain/memories.md` using the M-XXX-NNN entry format from the `telamon.memory_management` skill (section 6)

One entry per lesson — do not bundle multiple takeaways.

## 3. Pruning

When memories.md exceeds 100 entries, follow the pruning rules in the `telamon.memory_management` skill (section 6).
