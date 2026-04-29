---
name: telamon.remember_gotcha
description: "Write a gotcha to brain/gotchas.md when a trap, constraint, or recurring bug is discovered. Use immediately when hitting a non-obvious problem that others would stumble on."
---

# Remember Gotcha

Write a gotcha entry the moment you hit a trap, constraint, or recurring bug that is non-obvious 
and would trip up future agents or developers.

## When to Apply

- A tool or API behaves unexpectedly due to undocumented constraints
- A fix took multiple attempts because the root cause was non-obvious
- A configuration, platform, or environment quirk caused silent failure
- A pattern that looks correct actually breaks in a specific context

## Procedure

### 1. Write to `.ai/telamon/memory/brain/gotchas.md`

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
- Include the *why* — future agents need to understand the mechanism

### 2. Link check

The entry in `.ai/telamon/memory/brain/gotchas.md` must reference context via `[[wikilink]]` 
if it relates to a known pattern, decision, or other gotcha. If it stands alone, no link is 
required (gotchas.md itself is already linked from bootstrap).

## Do NOT use this skill for

- Decisions (use `brain/key_decisions.md` directly or `telamon.remember_lessons_learned`)
- Patterns (use `brain/patterns.md` directly or `telamon.remember_lessons_learned`)
- General lessons (use `telamon.remember_task`)
