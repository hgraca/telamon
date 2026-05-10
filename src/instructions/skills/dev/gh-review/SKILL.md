---
name: telamon.gh_review
description: "Addresses code review comments on a GitHub PR. Use when a PR has external review comments that need to be resolved — either by explaining reasoning or making code changes."
---

# Skill: GitHub PR Review Resolution

Address all code review comments on a GitHub PR by reading comments, making code changes, and explaining reasoning.

## When to Apply

- When a GitHub PR has review comments that need to be addressed
- When invoked via the `/telamon.gh_review` command with a PR number

## Input

PR number (`$1`).

## Procedure

### Step 1: Read PR comments

Use the `gh` CLI to read all review comments on PR `$1`. Prefer `--json` output and pipe through `cat` to avoid shell-piping truncation:

- `gh pr view $1 --json title,body,state,comments`
- `gh api repos/{owner}/{repo}/pulls/$1/comments` — line-anchored review comments (the most relevant ones)
- `gh api repos/{owner}/{repo}/pulls/$1/reviews` — top-level review summaries

### Step 2: Ensure correct branch

Use the `git` MCP to verify you are on the branch associated with the PR. Switch if needed.

### Step 3: Address each comment

For each review comment:

1. **If no code change needed** — reply to the comment on the PR explaining the reasoning and resolve the comment.
2. **If code change needed** — make the change and commit. One commit per comment addressed. Use a descriptive commit message referencing the review comment. Reply to the comment on the PR explaining the reasoning and resolve the comment.

### Step 4: Improve reviewer

After all comments are addressed, follow the `telamon.improve_reviewer` skill to improve the reviewer agent and/or its skills based on the issues found by the external reviewer in this session.

## MUST

- Address every unresolved comment — do not skip any.
- One commit per code-change comment — keep changes atomic and traceable.
- Explain reasoning clearly for all comments addressed.

## MUST NOT

- Ignore or dismiss review comments without explanation.
- Bundle multiple comment fixes into a single commit.
