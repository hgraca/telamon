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

- Use `git mv` for renames, to keep the git history
- **Run `make test` before every commit** — delegate `make test` to @tester and confirm all tests pass BEFORE staging and committing. Never commit code that has not been validated by the full test suite. If tests fail, fix the issue first; do not commit broken code.
- **Commit after every completed task** — any work that changes files must be committed before reporting results to the user. Never leave file changes uncommitted after finishing a task.
- Files or folders under a path ignored by git must NEVER be committed, unless explicitly done or requested by the human stakeholder
- When a ticket ID is provided together with the task, use it as the commit title prefix, ie `POS-666: ...`
- When no ticket is provided with the task, use the conventional commits pattern

## Conventions
(shamelessly stolen from [Pauline Vos](https://github.com/paulinevos/claude-stuff/blob/main/skills/version-control/SKILLS.md#conventions))

### Atomic commits
Atomic commits are commits that are organized by purpose. Atomic commits have three features:

- Single, irreducible unit. Every commit pertains to one coherent set of changes, as small as possible without breaking anything.
- Everything works. Don't break the build or test suite on any commit.
- Clear and concise. The commit changes one thing, and its purpose is clear from commit message and description.

The opposite of an atomic commit is a "checkpoint commit": a commit that is created in a linear fashion,
committing as you go like a save point in a video game. This is not what we want to achieve.
This means that when making new changes that pertain to an existing commit, those changes should be
added to that commit instead of being placed in a new commit. It also means that changes that serve
different purposes do not go in a single commit.

### Commit message conventions
- Separate subject from body with a blank line
- Do not end the subject line with a period
- Capitalize the subject line and each paragraph
- Use the imperative mood in the subject line
- Wrap lines at 72 characters
- Use the subject line to describe what has changed
- Use the description to describe why the changes were needed
- Don't go into detail technical implementation -- that will be apparent from the diff.
