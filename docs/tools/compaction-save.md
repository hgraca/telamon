---
layout: page
title: Compaction Save
description: OpenCode plugin that saves compaction timestamps to active work items.
nav_section: docs
---

Compaction Save — Persist Compaction State to Active Work

An OpenCode plugin that writes a `compaction.md` file to each active work item directory during session compaction. This lets the agent know when compaction last occurred for each task.

- Automatic — fires during session compaction
- Writes `compaction.md` with an ISO timestamp to each active task directory
- Pushes active work context into the compacted session for continuity

**Type:** Built-in OpenCode plugin (`src/plugins/compaction-save.js`)

## How it works

1. On the `experimental.session.compacting` event:
   - Scans `.ai/telamon/memory/work/active/` for subdirectories with a `README.md`
   - Extracts the task title from the README frontmatter
   - Writes `compaction.md` with a `compacted_at` ISO timestamp and task title
   - Pushes an entry to `output.context` for each active work item
2. If `compaction.md` already exists, it is overwritten with the latest timestamp
3. If no active work items exist, does nothing

## Related

- [Active Work Context](active-work-context) — Injects active work items at session start
- [Session Capture](session-capture) — Auto-promotes learnings before compaction
