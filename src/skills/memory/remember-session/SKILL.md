---
name: telamon.remember_session
description: "Unified memory capture — the sole storage trigger (besides checkpoints). Scans the session since last watermark, routes findings to brain/ notes, promotes thinking/ drafts. Fires automatically on idle via remember-session plugin, or manually on 'wrap up'."
---

# Remember Session

The **primary memory storage mechanism**. All session learnings flow through this skill.

**Triggers:**
- **Automatic**: remember-session plugin fires this on `session.idle` (background, no user report)
- **Manual**: user says "wrap up", "wrapping up", "let's wrap" (produces a report)

**This skill replaces** the previous multi-trigger approach (`remember_lessons_learned`, `remember_task`, `remember_gotcha` used proactively). Those skills remain as utility references for entry formats, but agents no longer call them proactively during work.

## 0. Check watermark

Find: `.ai/telamon/memory/thinking/.last-capture-<worktree-dirname>.json`

Where `<worktree-dirname>` is the lowercase basename of the current working directory.

- If exists: only process content produced *after* the recorded `timestamp`. Use `git log --oneline --after="<timestamp>" --no-merges` to scope commit history.
- If does not exist: first capture for this worktree — process all session content.
- **If nothing happened since the watermark** (no commits, no meaningful conversation): update the watermark timestamp and exit. Do not produce empty entries.

## 1. Identify what happened

Scan the session (since watermark) for:
- **Decisions made** — architectural choices, product direction, human stakeholder answers
- **Patterns discovered** — approaches that worked and should be repeated
- **Gotchas hit** — bugs, traps, constraints, false assumptions
- **Work completed** — issue folders touched, tasks finished
- **Rules given** — new rules or constraints from the stakeholder

Also check:
- `git log --oneline --after="<watermark or 4 hours ago>" --no-merges`
- `.ai/telamon/memory/thinking/` for scratch files from this session

**If nothing worth capturing**: update watermark and exit (step 5). Skip steps 2-4.

## 2. Route to brain notes

Append new entries to the appropriate brain/ file per the routing table in the `telamon.memory_management` skill (section 2):

| Finding | Destination | Format |
|---------|-------------|--------|
| Product decision, stakeholder answer, new rule | `brain/PDRs.md` | Decision + rationale |
| Architecture/technical decision | `brain/ADRs.md` | Decision + rationale |
| Trap, constraint, recurring bug | `brain/gotchas.md` | Problem + fix/workaround |
| Established pattern | `brain/patterns.md` | Pattern + when to apply |
| Reusable lesson | `brain/memories.md` | M-XXX-NNN format (see `telamon.memory_management` skill, section 6) |

**Quality gate**: Only save entries that are specific, actionable, and include context. Generic observations ("be careful with X") are not worth saving.

## 3. Promote or discard thinking notes

Follow the thinking/ lifecycle rules in the `telamon.memory_management` skill (section 7):
- Contains a reusable lesson → promote to brain/, then delete
- Completed work → delete
- Still live WIP → keep

## 4. Verify vault links

New notes must link to at least one existing note via `[[wikilink]]` (see `telamon.memory_management` skill, section 4).

## 5. Update watermark

Write/update `.ai/telamon/memory/thinking/.last-capture-<worktree-dirname>.json`:

```json
{
  "timestamp": "<ISO 8601 now>",
  "worktree": "<worktree or directory path>"
}
```

## 6. Report (manual wrap-up only)

**Skip this step entirely when triggered by the remember-session plugin** (automated idle capture).

When triggered by user ("wrap up"), present:
- **Captured**: what was added to brain notes and where
- **Promoted**: what was promoted from thinking/ to brain/
- **Remaining**: anything left for next session (with thinking/ note)
