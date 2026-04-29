---
tags: [bootstrap, session, memory]
description: Memory skill guide — when to use each skill during a session
---

## Session — Memory Skills

### Session start (mandatory):
Load the `telamon.recall_memories` skill — switches memory profile, recalls past context, reads brain/ notes, initializes knowledge tools.

### While working:
| When...                                                       | Load skill                         |
|---------------------------------------------------------------|------------------------------------|
| You make a decision, fix a non-trivial bug, or spot a pattern | `telamon.remember_lessons_learned` |
| You hit a trap, constraint, or recurring bug                  | `telamon.remember_gotcha`          |
| You need a scratch file, draft, or WIP note                   | `telamon.thinking`                 |

### After completing a task:
Load the `telamon.remember_task` skill — reviews what was learned, updates brain/memories.md, stores lessons.

### Before context overflow:
Load the `telamon.remember_checkpoint` skill — saves working state, promotes learnings, then recalls after compaction.

### Wrapping up ("wrap up" / ending session):
Load the `telamon.remember_session` skill — captures everything worth keeping, routes to brain/ notes, archives work, reports what was saved.

### Switching projects:
Load the `telamon.recall_memories` skill for the new project.

## See also

- [[memories]]
- [[PDRs]]
- [[ADRs]]
- [[patterns]]
- [[gotchas]]
