---
name: telamon.remember_session
description: "Capture everything worth keeping when a session ends. Check watermark, identify what happened, route to brain/ notes, promote or discard thinking/ drafts, verify vault links. Use when wrapping up, ending a session, or going idle."
---

# Remember Session

Triggers: user says "wrap up", "wrapping up", "let's wrap", session going idle, or you are about to end a session.

## 0. Check watermark

Find: `.ai/telamon/memory/thinking/.last-capture-<worktree-dirname>.json`

Where `<worktree-dirname>` is the lowercase basename of the current working directory.

- If exists: only process content produced *after* the recorded `timestamp`. Use `git log --oneline --after="<timestamp>" --no-merges` to scope commit history.
- If does not exist: first capture for this worktree — process all session content.

## 1. Identify what happened

Scan the session for:
- **Decisions made** — architectural choices, product direction, human stakeholder answers
- **Patterns discovered** — approaches that worked and should be repeated
- **Gotchas hit** — bugs, traps, constraints, false assumptions
- **Work completed** — issue folders touched, tasks finished
- **Freeform notes** — anything the user mentioned that wasn't filed

Also check:
- `git log --oneline --after="<watermark or 4 hours ago>" --no-merges`
- `.ai/telamon/memory/thinking/` for scratch files from this session

## 2. Route to brain notes

Append new entries to the appropriate brain/ file per the routing table in the `telamon.memory_management` skill (section 2):
- **Traps, constraints, or recurring bugs** → use the `telamon.remember_gotcha` skill (writes to `brain/gotchas.md`)
- **Lessons for memories.md** → use the M-XXX-NNN entry format from the `telamon.memory_management` skill (section 6)
- **Decisions, patterns** → append directly to the appropriate brain/ file

## 3. Promote or discard thinking notes

Follow the thinking/ lifecycle rules in the `telamon.memory_management` skill (section 7).

## 4. Verify vault links

New notes must link to at least one existing note via `[[wikilink]]` (see `telamon.memory_management` skill, section 4).

## 5. Update watermark

Write/update `.ai/telamon/memory/thinking/.last-capture-<worktree-dirname>.json` with current timestamp.

## 6. Report (manual wrap-up only)

When triggered by user (not automated idle), present:
- **Captured**: what was added to brain notes and where
- **Promoted**: what was promoted from thinking/ to brain/
- **Remaining**: anything left for next session (with thinking/ note)
