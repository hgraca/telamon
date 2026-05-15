---
description: Show git state snapshot — branch, status, staged diff, recent commits, commits ahead of default branch
agent: telamon/telamon
---

Invoke `git-report` tool to snapshot current git state. Returns current branch, default remote branch, recent commits, working-tree status, staged diff (summary + full), and commits ahead of origin/HEAD. Supports --format markdown|json and --log-count N flags.
