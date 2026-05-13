---
description: Archive a completed work note — move it from work/active/ to work/archive/ and update related references
---

Archive following work note: $1

## 1. Locate Note

Find file in `.ai/telamon/memory/work/active/` matching argument (by name or slug). If ambiguous, list candidates and ask.

## 2. Verify Complete

Before archiving:
- Confirm note has clear resolution or outcome recorded
- Check related `.ai/telamon/memory/work/active/` folder has `DONE.md` for completed tasks
- Confirm no open action items remain (unchecked `- [ ]` items)

If unresolved items exist, list them and ask user before proceeding.

## 3. Move to Archive

```bash
git mv .ai/telamon/memory/work/active/<filename>.md .ai/telamon/memory/work/archive/<filename>.md
```

Add `**Archived**: <YYYY-MM-DD>` line to top of file under title.

## 4. Update References

Check if other vault files link to this note:
- Search `.ai/telamon/memory/brain/` for filename
- Search `.ai/telamon/memory/work/active/` and `.ai/telamon/memory/work/archive/` for filename

For each reference found, update link path from `work/active/` to `work/archive/`.

## 5. Promote Lessons

Scan archived note for:
- Gotchas or traps → append to `.ai/telamon/memory/brain/gotchas.md`
- Reusable patterns → append to `.ai/telamon/memory/brain/patterns.md`
- Standing product decisions → add to `.ai/telamon/memory/brain/PDRs.md`
- Standing architecture decisions → add to `.ai/telamon/memory/brain/ADRs.md`

## 6. Report

Summarise:
- **Archived**: file moved from → to
- **References updated**: files with updated links
- **Lessons promoted**: anything added to brain notes