---
name: telamon.remember_checkpoint
description: "Save a checkpoint before context overflow. Persist working state to Ogham, promote learnings to brain/ notes, compact, then recall. Use when context nears limit, responses slow down, or opencode warns of compaction."
---

# Remember Checkpoint

Triggers: repetition in responses, slow output, opencode warns of compaction.

## Procedure

1. **Checkpoint**: `ogham store "checkpoint: <task> — done: <X> — next: <Y>"`
2. **Promote**: Save any new learnings to the relevant brain/ note (key_decisions.md, patterns.md, gotchas.md, memories.md)
3. **Compact**: Run `/compact` in opencode
4. **Recall**: After compaction, search Ogham — `ogham search "checkpoint"` — and re-read relevant brain/ notes to re-anchor goals
