---
name: telamon.remember_gotcha
description: "Write gotcha to latent/global/<technology>/ or latent/project/ when trap, constraint, or recurring bug discovered. Use immediately when hitting non-obvious problem others would stumble on."
---

# Remember Gotcha

Write gotcha entry moment you hit trap, constraint, or recurring bug that is non-obvious and would trip up future agents or developers.

## When to Apply

- Tool or API behaves unexpectedly due to undocumented constraints
- Fix took multiple attempts because root cause was non-obvious
- Configuration, platform, or environment quirk caused silent failure
- Pattern that looks correct actually breaks in specific context

## Procedure

### 1. Decide destination

- Reusable across projects (tech-specific trap) → `latent/global/<technology>/`
- Specific to this project's domain or architecture → `latent/project/`

See routing rules in `telamon.memory_management` skill (section 2).

### 2. Create new file

File naming: `YYYYMMDDHHMMSS-NN-<max-10-word-subject>.md`

File template:

```markdown
---
date: YYYY-MM-DD
tags: ["latent", "global"]
keywords: ["word1", "word2", ...]
source: <session or context>
---

## <Short descriptive title>

- **Date**: YYYY-MM-DD
- **Context**: <What triggered this — tool, API, platform, config quirk.>
- **Lesson**: <What went wrong, why it's non-obvious, and context where it occurs. Include fix or workaround. File paths, commands, or code if helpful.>
- **Scope**: <Technology or project area where this applies.>
- **Status**: ACTIVE
```

Quality criteria (from `telamon.memory_management` skill, section 5):
- Reproducible problem + fix or workaround
- Specific, not generic ("BSD sed requires empty backup arg" not "sed works differently on macOS")
- Include *why* — future agents need mechanism

### 3. Link check

Entry must reference context via `[[wikilink]]` if it relates to known pattern, decision, or other gotcha. If standalone, no link required.

## Do NOT use this skill for

- Decisions (use `latent/PDRs/` or `latent/ADRs/` directly, or `telamon.remember_lessons_learned`)
- General lessons without a concrete trap (use `telamon.remember_task`)