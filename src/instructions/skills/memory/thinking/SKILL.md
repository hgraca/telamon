---
name: telamon.thinking
description: "Scratch files, drafts, and WIP content management. Use when creating temporary files, ephemeral notes, partial-progress checkpoints, or any non-formal artifact during a session. Triggers: 'scratch file', 'temp file', 'draft', 'WIP', 'partial progress'."
---

# Thinking -- Scratch Files & Drafts

All ephemeral scratch files, notes, drafts, or WIP content produced during a session (not a formal artifact) must be saved to `<proj>/.ai/telamon/memory/thinking/`. Do not create temporary ad-hoc files elsewhere.

## When to Apply

- Creating any temporary file, ephemeral note, draft, or WIP content
- Saving partial-progress checkpoints before context overflow
- Deciding whether to promote or delete existing scratch files

## 1. Naming

| Content | Filename |
|---|---|
| General scratch / draft | `<descriptive-name>.md` |
| Partial-progress checkpoint | `YYYY-MM-DD-HH:MM:SS-<task>-partial.md` |

## 2. Lifecycle

After the task completes or the session ends:

1. **Promote**: If the file contains lasting value (decision, pattern, gotcha), move its content to the appropriate brain/ note.
2. **Delete**: Remove files that add no lasting value.
3. **Flag**: Any `thinking/` file older than 7 days should be reviewed -- promote or delete.

See the `telamon.memory_management` skill (section 7) for full lifecycle rules.
