---
name: session-capture
description: "Capture everything worth keeping from the current session. Runs automatically after the agent goes idle (session.idle) and on explicit wrap-up. Promotes learnings to brain/ notes, routes freeform content to the right vault files, cleans up thinking/ drafts, and saves to Ogham."
---

# Session Capture

Run this when the agent goes idle or when wrapping up a session. It combines memory promotion, freeform routing, and cleanup into a single pass.

## 0. Check Last-Capture Watermark

Watermark files are scoped per git worktree so concurrent agents in different
worktrees track their own capture history independently.

Find the watermark for the current worktree:
`.ai/adk/memory/thinking/.last-capture-<worktree-dirname>.json`

Where `<worktree-dirname>` is the lowercase basename of the current working
directory (e.g. `my-project`, `my-project-feat-auth`).

- If the file **exists**: only process content produced *after* the `timestamp`
  recorded there. Use `git log --oneline --after="<timestamp>" --no-merges` to
  scope commit history. Skip anything already filed.
- If it **does not exist**: this is the first capture for this worktree —
  process all session content.

## 1. Identify What Happened

Scan the session for things worth keeping:

- **Decisions made** — architectural choices, product direction, human stakeholder answers
- **Patterns discovered** — approaches that worked and should be repeated
- **Gotchas hit** — bugs, traps, constraints, false assumptions
- **Work completed or progressed** — issue folders touched, tasks finished
- **Freeform notes** — anything the user dumped or mentioned that wasn't filed

Also check:
- `git log --oneline --after="<last-capture timestamp, or 4 hours ago if first run>" --no-merges` for recent commits
- `.ai/adk/memory/thinking/` for existing scratch files from this session

## 2. Route to Brain Notes

Append new entries to the appropriate file. Do not overwrite; add to existing sections.

| Content | Destination |
|---|---|
| Architectural or product decision | `.ai/adk/memory/brain/key_decisions.md` |
| Human stakeholder answer to a project question | `.ai/adk/memory/brain/key_decisions.md` |
| Reusable pattern or best practice | `.ai/adk/memory/brain/patterns.md` |
| Bug, trap, or known constraint | `.ai/adk/memory/brain/gotchas.md` |
| General project knowledge or context | `.ai/adk/memory/brain/memories.md` |
| Active work note | `.ai/adk/memory/work/active/<name>.md` |
| Completed work note | `.ai/adk/memory/work/archive/YYYY/<name>.md` |
| Incident | `.ai/adk/memory/work/incidents/<YYYY-MM-DD>-<slug>.md` |
| Ephemeral draft still needed | `.ai/adk/memory/thinking/<descriptive-name>.md` |

**Routing rules:**
- Append, don't replace — add to existing sections rather than overwriting
- One entry per insight — don't bundle multiple takeaways into one entry
- Be specific — "always pass `--no-interaction` to Artisan" beats "be careful with CLI"
- Include date for new brain entries

## 3. Promote or Discard Thinking Notes

For each file in `.ai/adk/memory/thinking/`:
- Contains a reusable lesson? → promote to the right brain file, then **delete** the thinking note
- Completed partial-progress note? → **delete** it (the work is done)
- Still live WIP? → keep it; rename to `partial-<task>-YYYY-MM-DD.md` if not already descriptive

Flag any thinking/ file older than 7 days for user review.

## 4. Update Ogham

Run `ogham hooks inscribe` to persist session activity to the semantic memory store.

Explicitly store anything important that ogham might not pick up automatically:
- `ogham store "decision: X over Y because Z"`
- `ogham store "bug: <desc and fix>"`
- `ogham store "pattern: <desc>"`

## 5. Verify Vault Links

New notes must link to at least one existing note via `[[wikilink]]`. An orphan note (no links) is a bug — link it or delete it.

## 6. Report (on explicit wrap-up only)

When triggered manually (not by the automated session.idle plugin), present a concise summary:
- **Captured**: what was added to brain notes and where
- **Promoted**: what was promoted from thinking/ to brain files
- **Saved**: what was sent to Ogham
- **Remaining**: anything explicitly left for next session (with a thinking/ note)
