---
name: telamon.remember_lessons_learned
description: "Capture knowledge as you work. Save decisions, patterns, bugs, and rules to Ogham and brain/ notes the moment they arise. Use continuously during work — do not defer to end of session."
---

# Remember Lessons Learned

As you work, capture knowledge the moment it arises. Do not defer to end of session.

## What to save and where

| What happened | Ogham | Brain/ file |
|---|---|---|
| Decision made (architectural or product) | `ogham store "decision: X over Y because Z"` | Append to `brain/key_decisions.md` |
| Human stakeholder answers a question | `ogham store "decision: <Q> → <A>"` | Append to `brain/key_decisions.md` |
| New rule given by stakeholder | `ogham store "rule: <rule>"` | Append to `brain/key_decisions.md` |
| Bug fixed (non-trivial) | `ogham store "bug: <desc and fix>"` | Append to `brain/gotchas.md` if recurring |
| Pattern established | `ogham store "pattern: <desc>"` | Append to `brain/patterns.md` |
| Graphiti enabled? | Also save decisions and relationships via Graphiti `add_episode` | — |

## What NOT to save

Never save: `ls`/`git status`/`cat`/`pwd` output, secrets, trivial single-line edits.

## Memory tiers

For reference — understand which tier you are writing to:

| Tier | Store | What goes here | Who writes |
|---|---|---|---|
| **Working** | AGENTS.md + session context | Active goals, current task state, in-flight constraints | Human + agent at session start |
| **Episodic** | Ogham + cass | Past actions, bugs fixed, patterns discovered, session logs | Agent automatically during/after sessions |
| **Long-term** | Obsidian brain/ notes | Architectural decisions, domain knowledge, patterns, gotchas | Agent deliberately at wrap-up, human for strategy |
