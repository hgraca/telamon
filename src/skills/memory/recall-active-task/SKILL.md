---
name: telamon.recall_active_task
description: "Recall an active task status. Read a task summary, backlog and compaction to understand the task context and status. Use when resuming work on an in-progress task after a session break or context compaction."
---

# Recall Active Task

Recover full context for an in-progress task after a session break, compaction, or context loss.

## When to Apply

- User says "continue task", "resume task" or names a specific task
- When starting a new session and `.ai/telamon/memory/work/active/` contains folders

## Procedure

### Step 1: Identify the active task

List `.ai/telamon/memory/work/active/` to find task folders.

- **No folders**: Report "No active tasks found" — stop here.
- **One folder**: Use it.
- **Multiple folders**: Present the list to the user and ask which task to resume. If the user named a specific task, match by slug.

### Step 2: Recover task context

Read the following files from the task folder (skip any that do not exist):

| File                 | Purpose                                                |
|----------------------|--------------------------------------------------------|
| `summary.md`         | Planning summary — scope, decisions, deliverables      |
| `backlog.md`         | Task list with status, acceptance criteria, priorities |
| `compaction.md`      | Last checkpoint — progress snapshot, next steps        |
| `ARCH-*.md`          | Architecture specification                             |
| `UI-*.md`            | UI specification                                       |
| `UX-*.md`            | UX specification                                       |

Priority order: `compaction.md` first (most recent state), then `backlog.md` (task status), then `summary.md` (overall scope).

### Step 3: Recover Ogham context

Use the `telamon.ogham` skill to search for the task name or slug — retrieve checkpoints, decisions, and lessons from prior sessions on this task.

### Step 4: Determine current position

From the recovered context, identify:

1. **Last completed task** — the most recent task marked done (strikethrough) in `backlog.md`
2. **Current task** — the first non-completed task in priority order
3. **Blockers** — any BLOCKED signals or unresolved questions noted in `compaction.md`
4. **Stage** — is this task in planning or implementation?

### Step 5: Report to user

Output a brief status:

> **Task**: `<folder-name>`
> **Stage**: Planning | Implementation
> **Progress**: `<completed>`/`<total>` tasks done
> **Next**: `<current task title>`
> **Blockers**: `<any>` or None

### Step 6: Resume work

- If in **planning** stage: load the `telamon.plan_story` skill and continue from the appropriate step.
- If in **implementation** stage: load the `telamon.implement_story` skill and continue the task cycle from the current task.
- If **blocked**: present blockers to the user and wait for resolution before proceeding.
