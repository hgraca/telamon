---
description: Deep structural audit of the memory vault — check folder placement, latent note quality, thinking/ hygiene, and issue folder consistency
---

Deep structural audit of `.ai/telamon/memory/`. Fix fixable; flag what needs user input. For vault structure, routing, and quality rules, load `telamon.memory_management` skill.

**When to use**: After substantial sessions, after reorganisation, or periodically to maintain vault health. For lighter end-of-session checks, say "wrap up" to trigger `telamon.remember_session` skill.

## 1. Check Folder Structure

Verify vault matches expected layout:
- `latent/` contains exactly: `memories.md`, `PDRs.md`, `ADRs.md`, `patterns.md`, `gotchas.md`
- `work/active/` contains only active work notes
- `work/archive/` contains only completed work notes
- `work/incidents/` contains only incident notes
- `thinking/` — stale drafts that should be promoted or deleted?
- `reference/` — reference files current and not duplicated elsewhere?
- `bootstrap/` — bootstrap files intact (symlinks; verify they resolve)

## 2. Check Latent Note Quality

For each file in `latent/`:
- Content current? Flag stale or contradictory entries.
- File naming follows `YYYYMMDDHHMMSS-NN-<subject>.md` pattern (NN = integer starting at 01, resets per timestamp)?
- `global/<tech>/` — entries reusable across projects, tech-specific, with context?
- `PDRs/` — entries have rationale, not just decision?
- `ADRs/` — entries have rationale, not just decision?

- `project/` — entries project-specific with domain context?

## 3. Check Thinking/ Hygiene

For each file in `thinking/`:
- Partial-progress note now completed? → delete
- Contains reusable lesson? → promote to latent, delete draft
- Genuinely live WIP? → keep, verify filename descriptive

Flag thinking/ file older than 7 days for user review.

## 4. Check Issue Folder Consistency

For each folder in `.ai/telamon/memory/work/active/`:
- `backlog.md` exists with accurate task statuses?
- Orphaned artifacts (e.g. `DONE.md` with no corresponding task)?
- Duplicate issue folders for same initiative?
- Folder name follows `YYYYMMDD-HHMMSS-NN-<title_slug>` convention?

## 5. Check Reference Files

For each file in `reference/`:
- Still accurate? (check against current project conventions)
- Linked from or referenced by any latent file?
- Duplicates between `reference/` and `latent/`?

## 6. Fix and Report

Fix clearly wrong items (stale entries, misplaced files, broken symlinks).
For ambiguous issues, list them and ask user.

Summarise:
- **Fixed**: issues resolved automatically
- **Flagged**: items requiring user input
- **Suggested**: improvements for vault structure