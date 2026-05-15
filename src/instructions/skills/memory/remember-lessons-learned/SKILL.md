---
name: telamon.remember_lessons_learned
description: "Capture knowledge as you work. Save decisions, patterns, bugs, and rules to brain/ notes moment they arise. Use continuously during work — do not defer to end of session."
---

# Remember Lessons Learned

As you work, capture knowledge moment it arises. Do not defer to end of session.

## What to save and where

| What happened                                   | Action                                                             |
|-------------------------------------------------|--------------------------------------------------------------------|
| Decision made (product, requirements, business) | New file in `brain/PDRs/`                                          |
| Decision made (architecture, technical)         | New file in `brain/ADRs/`                                          |
| Human stakeholder answers question              | Categorize → new file in `brain/PDRs/` or `brain/ADRs/`          |
| New rule given by stakeholder                   | Categorize → new file in `brain/PDRs/` or `brain/ADRs/`          |
| Bug fixed (non-trivial)                         | Use `telamon.remember_gotcha` skill to new file in `brain/gotchas/` |
| Pattern established                             | New file in `brain/patterns/`                                      |

## How to categorize decision

| Category     | File            | Signals                                                                                                                                                               |
|--------------|-----------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Product      | `brain/PDRs/` | Requirements, UX, documentation structure, user-facing behavior, business rules, priorities, feature scope, naming from user perspective, communication format        |
| Architecture | `brain/ADRs/` | Tool choices, storage locations, protocols, code patterns, agent/system design, infrastructure, ports, deployment, testing strategy, file placement, dependency rules |

**Rule of thumb:** Answers "what should system do / how should it look to users?" → PDRs. Answers "how should we build / structure / deploy it?" → ADRs.

For vault routing (which brain/ file to append to), see `telamon.memory_management` skill (section 2).

## What NOT to save

See `telamon.memory_management` skill, section 4 (Never write) for full list. Key rule: never save secrets, command output, or trivial edits.