---
name: telamon.remember_lessons_learned
description: "Capture knowledge as you work. Save decisions, patterns, bugs, and rules to brain/ notes the moment they arise. Use continuously during work — do not defer to end of session."
---

# Remember Lessons Learned

As you work, capture knowledge the moment it arises. Do not defer to end of session.

## What to save and where

| What happened | Action |
|---|---|
| Decision made (product, requirements, business) | Append to `brain/PDRs.md` |
| Decision made (architecture, technical) | Append to `brain/ADRs.md` |
| Human stakeholder answers a question | Append to `brain/PDRs.md` |
| New rule given by stakeholder | Append to `brain/PDRs.md` |
| Bug fixed (non-trivial) | Use the `telamon.remember_gotcha` skill to write to `brain/gotchas.md` |
| Pattern established | Append to `brain/patterns.md` |

For vault routing (which brain/ file to append to), see the `telamon.memory_management` skill (section 2).

## What NOT to save

See the `telamon.memory_management` skill, section 4 (Never write) for the full list. Key rule: never save secrets, command output, or trivial edits.
