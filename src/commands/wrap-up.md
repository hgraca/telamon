---
description: End-of-session review — verify memory notes, promote thinking/ drafts, and capture lessons learned
---

Full session review before ending. Triggered when the user says "wrap up", "let's wrap", or similar.

## 1. Review What Was Done

Scan the session for:
- Code files modified (list with paths)
- Issue folder artifacts created or updated (`backlog.md`, `PLAN.md`, `ARCH-*.md`, `DONE.md`, etc.)
- Brain notes updated (`memories.md`, `key_decisions.md`, `patterns.md`, `gotchas.md`)
- Thinking notes created in `.ai/adk/memory/thinking/`

## 2. Promote or Discard Thinking Notes

For each file in `.ai/adk/memory/thinking/`:
- Does it contain a reusable lesson? → promote to the appropriate brain file and delete the thinking note
- Is it a completed partial-progress note? → delete it (the work is done)
- Is it still live WIP? → leave it with a clear filename (`partial-<task>-YYYY-MM-DD.md`)

## 3. Check Brain Note Quality

For each brain file that was updated or should have been:
- `memories.md` — does the Recent Context section reflect what happened this session?
- `key_decisions.md` — are new decisions recorded with rationale?
- `patterns.md` — did this session reveal a reusable pattern worth capturing?
- `gotchas.md` — did this session hit a trap or constraint worth recording?

## 4. Check Issue Folder Consistency

For each active `.ai/issue/` folder:
- Are all task statuses in `backlog.md` accurate?
- Does `DONE.md` exist for completed tasks?
- Are there stale artifacts from earlier rounds that can be deleted?

## 5. Ways of Working

Check if this session revealed:
- A new pattern for `patterns.md`?
- A new gotcha for `gotchas.md`?
- A standing decision for `key_decisions.md`?
- A needed update to an agent, skill, or command file?

## 6. Report

Present a concise summary:
- **Done**: what was accomplished this session
- **Captured**: what was added to brain notes
- **Promoted**: what was promoted from thinking/ to brain files
- **Remaining**: what is explicitly left for next session (with a thinking/ note)
- **Suggested**: any workflow improvements noticed

This is a READ + VERIFY pass. Fix small issues inline; flag larger changes for user approval.
