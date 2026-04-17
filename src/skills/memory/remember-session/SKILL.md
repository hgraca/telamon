---
name: telamon.remember_session
description: "Capture everything worth keeping when a session ends. Check watermark, identify what happened, route to brain/ notes, promote or discard thinking/ drafts, update Ogham, verify vault links. Use when wrapping up, ending a session, or going idle."
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

Append new entries. Do not overwrite.

| Content                           | Destination                                                                                            |
|-----------------------------------|--------------------------------------------------------------------------------------------------------|
| Architectural or product decision | `.ai/telamon/memory/brain/key_decisions.md`                                                            |
| Human stakeholder answer          | `.ai/telamon/memory/brain/key_decisions.md`                                                            |
| Reusable pattern or best practice | `.ai/telamon/memory/brain/patterns.md`                                                                 |
| Bug, trap, or known constraint    | `.ai/telamon/memory/brain/gotchas.md`                                                                  |
| General project knowledge         | `.ai/telamon/memory/brain/memories.md` (using M-XXX-NNN format from the `telamon.remember_task` skill) |
| Active work note                  | `.ai/telamon/memory/work/active/<name>.md`                                                             |
| Completed work note               | `.ai/telamon/memory/work/archive/YYYY-MM-DD/<name>.md`                                                 |
| Incident                          | `.ai/telamon/memory/work/incidents/<YYYY-MM-DD>-<slug>.md`                                             |
| Ephemeral draft still needed      | `.ai/telamon/memory/thinking/<descriptive-name>.md`                                                    |

**Routing rules:**
- Append, don't replace
- One entry per insight
- Be specific — include dates
- When writing to `brain/key_decisions.md` and Graphiti is enabled (`telamon-graphiti` container running): also create a Graphiti entity via `add_episode` with `name` (decision title), `episode_body` (decision + rationale), `source` ("session-capture")

## 3. Promote or discard thinking notes

For each file in `.ai/telamon/memory/thinking/`:
- Contains a reusable lesson? → promote to brain/, then **delete** the thinking note
- Completed work? → **delete** (work is done)
- Still live WIP? → keep; rename to `partial-<task>-YYYY-MM-DD.md` if not descriptive

Flag any thinking/ file older than 7 days for user review.

## 4. Update Ogham

Store anything important not yet captured:
- `ogham store "decision: X over Y because Z"`
- `ogham store "bug: <desc and fix>"`
- `ogham store "pattern: <desc>"`

## 5. Verify vault links

New notes must link to at least one existing note via `[[wikilink]]`. An orphan note is a bug — link it or delete it.

## 6. Update watermark

Write/update `.ai/telamon/memory/thinking/.last-capture-<worktree-dirname>.json` with current timestamp.

## 7. Report (manual wrap-up only)

When triggered by user (not automated idle), present:
- **Captured**: what was added to brain notes and where
- **Promoted**: what was promoted from thinking/ to brain/
- **Saved**: what was sent to Ogham
- **Remaining**: anything left for next session (with thinking/ note)
