---
name: telamon.remember_gotcha
description: "Write gotcha to brain/gotchas.md when trap, constraint, or recurring bug discovered. Use immediately when hitting non-obvious problem others would stumble on."
---

# Remember Gotcha

Write gotcha entry moment you hit trap, constraint, or recurring bug that is non-obvious and would trip up future agents or developers.

## When to Apply

- Tool or API behaves unexpectedly due to undocumented constraints
- Fix took multiple attempts because root cause was non-obvious
- Configuration, platform, or environment quirk caused silent failure
- Pattern that looks correct actually breaks in specific context

## Procedure

### 1. Write to `.ai/telamon/memory/brain/gotchas.md`

After writing, run `format-md` on file to align table columns.

Append one entry using this format:

```markdown
## <Short descriptive title>
Module: <code-namespace|package|module>
Date: YYYY-MM-DD
<1-3 sentences: what went wrong, why it's non-obvious, and context where it occurs.>
Fix: <concrete fix or workaround. Include file paths, commands, or code if helpful.>
```

Quality criteria (from `telamon.memory_management` skill, section 5):
- Reproducible problem + fix or workaround
- Specific, not generic ("BSD sed requires empty backup arg" not "sed works differently on macOS")
- Include *why* — future agents need mechanism

### 2. Link check

Entry in `.ai/telamon/memory/brain/gotchas.md` must reference context via `[[wikilink]]` if it relates to known pattern, decision, or other gotcha. If standalone, no link required (gotchas.md itself already linked from bootstrap).

## Do NOT use this skill for

- Decisions (use `brain/PDRs.md` or `brain/ADRs.md` directly, or `telamon.remember_lessons_learned`)
- Patterns (use `brain/patterns.md` directly or `telamon.remember_lessons_learned`)
- General lessons (use `telamon.remember_task`)