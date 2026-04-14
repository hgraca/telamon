---
description: Morning kickoff — load today's context, surface open tasks, and identify priorities
---

Run the morning standup:

1. Read `.ai/adk/memory/brain/memories.md` — knowledge index and recent context
2. Read `.ai/adk/memory/brain/key_decisions.md` — current goals and standing decisions
3. Check `.ai/issue/` for active issue folders and their `backlog.md` files
4. Check recent git activity: `git log --oneline --since="24 hours ago" --no-merges`
5. Check for any uncommitted changes: `git status`
6. Scan `.ai/adk/memory/thinking/` for any partial-progress notes from previous sessions

Present a structured standup summary:

- **Yesterday**: What got done (from git log)
- **Active Work**: Current issue folders with their status (in-progress tasks from backlog.md)
- **Open Items**: Uncommitted work, stalled tasks, partial-progress notes in thinking/
- **Goal Alignment**: How active work maps to key decisions and project goals
- **Suggested Focus**: What to prioritize today based on goals + open items

Keep it concise. This is a quick orientation, not a deep dive.
