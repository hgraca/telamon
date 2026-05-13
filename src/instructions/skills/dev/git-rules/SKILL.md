---
name: telamon.git_rules
description: "Git commit conventions: gitignored paths, ticket ID prefixes, conventional commits. Use when committing code, writing commit messages, or checking what should be committed."
---

# Git

## When to Apply

- Committing code changes
- Writing commit messages
- Checking whether file should be committed

## Rules

- Use `git mv` for renames, to keep git history
- **Run `make test` before every commit** — delegate `make test` to @tester and confirm all tests pass BEFORE staging and committing. Never commit code not validated by full test suite. If tests fail, fix issue first; do not commit broken code.
- **Commit after every completed task** — any work changing files must be committed before reporting results to user. Never leave file changes uncommitted after finishing task.
- Files or folders under path ignored by git must NEVER be committed, unless explicitly done or requested by human stakeholder
- When ticket ID provided together with task, use it as commit title prefix, ie `POS-666: ...`
- When no ticket provided with task, use conventional commits pattern

## Conventions
(shamelessly stolen from [Pauline Vos](https://github.com/paulinevos/claude-stuff/blob/main/skills/version-control/SKILLS.md#conventions))

### Atomic commits
Atomic commits are commits organized by purpose. Atomic commits have three features:

- Single, irreducible unit. Every commit pertains to one coherent set of changes, as small as possible without breaking anything.
- Everything works. Don't break build or test suite on any commit.
- Clear and concise. Commit changes one thing, and its purpose clear from commit message and description.

Opposite of atomic commit is "checkpoint commit": commit created in linear fashion,
committing as you go like save point in video game. This is not what we want.
When making new changes pertaining to existing commit, those changes should be
added to that commit instead of placed in new commit. Changes serving
different purposes do not go in single commit.

### Commit message conventions
- Separate subject from body with blank line
- Do not end subject line with period
- Capitalize subject line and each paragraph
- Use imperative mood in subject line
- Wrap lines at 72 characters
- Use subject line to describe what changed
- Use description to describe why changes were needed
- Don't go into detail technical implementation -- that will be apparent from diff.