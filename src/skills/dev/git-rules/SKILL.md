---
name: telamon.git_rules
description: "Git commit conventions: gitignored paths, ticket ID prefixes, conventional commits. Use when committing code, writing commit messages, or checking what should be committed."
---

# Git

## When to Apply

- Committing code changes
- Writing commit messages
- Checking whether a file should be committed

## Rules

- Files or folders under a path ignored by git must NEVER be committed, unless explicitly done or requested by the human stakeholder
- When a ticket ID is provided together with the task, use it as the commit title prefix, ie `POS-666: ...`
- When no ticket is provided with the task, use the conventional commits pattern
