---
layout: page
title: Active Work Context
description: OpenCode plugin that injects active work items at session start and prompts the user to continue, archive, or start new work.
nav_section: docs
---

Active Work Context — Session-Start Work Resumption

An OpenCode plugin that injects a summary of active work items into the first bash call of each session. If active tasks exist, the agent asks the user whether to continue one, archive one, or start something new.

- Automatic — fires on the first bash call of each session
- Scans `.ai/telamon/memory/work/active/` for task directories
- Extracts task name, title, and short description from each `README.md`
- Injects context via the same echo-prefix pattern as [Diff Context](diff-context)

**Type:** Built-in OpenCode plugin (`src/plugins/active-work-context.js`)

## How it works

1. On the first `tool.execute.before` event where the tool is `bash`:
   - Reads all subdirectories under `.ai/telamon/memory/work/active/`
   - For each subdirectory with a `README.md`, extracts the title (first line after YAML frontmatter) and a short description (first paragraph after the title, max 200 chars)
   - Builds a context block listing all active items
   - Prepends the context to the bash command output
   - Includes an instruction for the agent to ask the user what to do
2. Fires only once per session (uses an `injected` flag)
3. If no active work items exist, skips silently

## Related

- [Compaction Save](compaction-save) — Saves compaction timestamps to active work items
- [Diff Context](diff-context) — Injects git change summary at session start
- [Session Capture](session-capture) — Auto-promotes learnings before compaction
