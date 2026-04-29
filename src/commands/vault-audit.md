---
description: Deep structural audit of the memory vault — check folder placement, brain note quality, thinking/ hygiene, and issue folder consistency
---

Deep structural audit of `.ai/telamon/memory/`. Fix what can be fixed; flag what needs user input. For vault structure, routing, and quality rules, load the `telamon.memory_management` skill.

**When to use**: After substantial sessions, after reorganisation, or periodically to maintain vault health. For lighter end-of-session checks, say "wrap up" to trigger the `telamon.remember_session` skill.

## 1. Check Folder Structure

Verify the vault matches the expected layout:
- `brain/` contains exactly: `memories.md`, `PDRs.md`, `ADRs.md`, `patterns.md`, `gotchas.md`
- `work/active/` contains only active work notes
- `work/archive/` contains only completed work notes
- `work/incidents/` contains only incident notes
- `thinking/` — are there stale drafts that should be promoted or deleted?
- `reference/` — are reference files current and not duplicated elsewhere?
- `bootstrap/` — are bootstrap files intact (these are symlinks; verify they resolve)

## 2. Check Brain Note Quality

For each file in `brain/`:
- Is the content current? Flag stale or contradictory entries.
- Are entries organised by section with clear headings?
- `memories.md` — are entries using M-XXX-NNN format with context and scope?
- `PDRs.md` — do entries have rationale, not just the decision?
- `ADRs.md` — do entries have rationale, not just the decision?
- `patterns.md` — are patterns actionable and specific?
- `gotchas.md` — are gotchas reproducible and with a fix or workaround?

## 3. Check Thinking/ Hygiene

For each file in `thinking/`:
- Is it a partial-progress note that's been completed? → delete
- Does it contain a reusable lesson? → promote to brain, delete the draft
- Is it genuinely live WIP? → keep, verify the filename is descriptive

Flag any thinking/ file older than 7 days for user review.

## 4. Check Issue Folder Consistency

For each folder in `.ai/telamon/memory/work/active/`:
- Does `backlog.md` exist and have accurate task statuses?
- Are there orphaned artifacts (e.g., `DONE.md` with no corresponding task)?
- Are there duplicate issue folders for the same initiative?
- Is the folder name following the `YYYYMMDD-HHMMSS-NN-<title_slug>` convention?

## 5. Check Reference Files

For each file in `reference/`:
- Is it still accurate? (check against current project conventions)
- Is it linked from or referenced by any brain file?
- Are there duplicates between `reference/` and `brain/`?

## 6. Fix and Report

Fix what is clearly wrong (stale entries, misplaced files, broken symlinks).
For ambiguous issues, list them and ask the user.

Summarise:
- **Fixed**: issues resolved automatically
- **Flagged**: items requiring user input
- **Suggested**: improvements for the vault structure
