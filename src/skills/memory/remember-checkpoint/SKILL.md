---
name: telamon.remember_checkpoint
description: "Save a checkpoint before context overflow. Persist working state to brain/ notes, compact, then recall. Use when context nears limit, responses slow down, or opencode warns of compaction."
---

# Remember Checkpoint

Triggers: repetition in responses, slow output, opencode warns of compaction.

## Procedure

1. **Promote**: Save any new learnings to the relevant brain/ note (see `telamon.memory_management` skill, section 2 for routing)
2. **Checkpoint**: Write a checkpoint note to `.ai/telamon/memory/thinking/` with current progress, next steps, and open questions (see `telamon.thinking` skill)
3. **Compact**: Run `/compact` in opencode
4. **Recall**: Re-read relevant brain/ notes to re-anchor goals and use the `telamon.recall_memories` skill to gather relevant context.
