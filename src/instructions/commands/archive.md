---
description: Archive a completed work note — move it from work/active/ to work/archive/ and update related references
---

Archive the following work note: $1

## 1. Locate the Note

Find the file in `.ai/telamon/memory/work/active/` matching the argument (by name or slug). If the argument is ambiguous, list candidates and ask.

## 2. Verify It's Complete

Before archiving:
- Confirm the note has a clear resolution or outcome recorded
- Check that any related `.ai/telamon/memory/work/active/` folder has a `DONE.md` for its completed tasks
- Confirm no open action items remain (unchecked `- [ ]` items)

If there are unresolved items, list them and ask the user before proceeding.

## 3. Move to Archive

```bash
git mv .ai/telamon/memory/work/active/<filename>.md .ai/telamon/memory/work/archive/<filename>.md
```

Add an `**Archived**: <YYYY-MM-DD>` line to the top of the file under the title.

## 4. Update References

Check if any other vault file links to this note:
- Search `.ai/telamon/memory/brain/` for the filename
- Search `.ai/telamon/memory/work/active/` and `.ai/telamon/memory/work/archive/` for the filename

For each reference found, update the link path from `work/active/` to `work/archive/`.

## 5. Promote Lessons

Scan the archived note for:
- Gotchas or traps → append to `.ai/telamon/memory/brain/gotchas.md`
- Reusable patterns → append to `.ai/telamon/memory/brain/patterns.md`
- Standing product decisions → add to `.ai/telamon/memory/brain/PDRs.md`
- Standing architecture decisions → add to `.ai/telamon/memory/brain/ADRs.md`

## 6. Report

Summarise:
- **Archived**: file moved from → to
- **References updated**: files that had their links updated
- **Lessons promoted**: anything added to brain notes
