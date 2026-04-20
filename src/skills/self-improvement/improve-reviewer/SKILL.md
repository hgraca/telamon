---
name: telamon.improve_reviewer
description: "Improves the reviewer agent and/or its skills so that issues detected by an external reviewer will be caught by our reviewer next time. Use at the end of a GitHub PR review resolution session."
---

# Skill: Improve Reviewer from External Feedback

Analyze external review comments addressed in the current session, identify gaps in our reviewer's detection capabilities, and propose improvements to the reviewer agent and/or its skills.

## When to Apply

- At the end of a `telamon.gh_review` skill execution
- When external PR review comments reveal issues our reviewer should have caught

## Goal

Improve the reviewer agent and/or its skills, so that the issues detected by the external reviewer will be detected by our reviewer next time.

## Procedure

### Step 1: Collect external review issues

Gather all review comments addressed in the current session. For each comment, classify:

| Field | Description |
|-------|-------------|
| **Issue** | What the external reviewer flagged |
| **Category** | Code quality, security, performance, architecture, naming, logic, testing, style |
| **Was it a code change?** | Did the comment result in a code change or just an explanation? |
| **Should our reviewer catch this?** | Yes / No / Already covered |

Filter to only issues where **should our reviewer catch this = Yes** and **already covered = No**.

### Step 2: Identify target files

For each gap, determine which file(s) need changes:

| Target | When |
|--------|------|
| `src/skills/workflow/review_changeset/SKILL.md` | New review check, modified check, new finding pattern |
| `src/agents/reviewer.md` | New responsibility, new MUST/MUST NOT rule, new skill reference |
| Other reviewer-referenced skills | If gap falls within an existing skill's scope |

Read target files before proposing changes.

### Step 3: Draft improvements

For each gap, draft a concrete change:

- **New review check** — add a numbered section to `review_changeset/SKILL.md` following the existing pattern (heading, bullet list of checks).
- **Strengthened existing check** — extend an existing section with additional verification steps.
- **New MUST/MUST NOT rule** — add to `reviewer.md` if it's a behavioral rule, not a procedure.
- **New skill reference** — add to reviewer's Skills section if a new skill covers the gap.

### Step 4: Present suggestions for approval

Present each suggestion to the human stakeholder:

> ### Suggestion N: \<title\>
>
> **External review issue**: \<what the external reviewer flagged\>
>
> **Gap**: \<why our reviewer didn't catch it\>
>
> **Target file**: \<path\>
>
> **Change**: \<description of the change\>
>
> **Rationale**: \<why this will prevent the gap next time\>

Ask for approval per suggestion: **Approve**, **Modify**, or **Skip**.

### Step 5: Implement approved suggestions

For each approved suggestion:

1. Apply changes to target files.
2. Verify structural consistency — YAML frontmatter, heading hierarchy, numbering sequence.
3. Record as a decision using `telamon.remember_lessons_learned` skill.
4. Commit: `git add <specific-files>`, verify with `git diff --staged --stat`, commit with descriptive message.

### Step 6: Summary

> ### Improve Reviewer Summary
>
> **External review comments analyzed**: N
> **Gaps identified**: N
> **Suggestions proposed**: N
> **Approved**: N / **Skipped**: N / **Modified**: N
>
> #### Changes applied
>
> - \<file\>: \<one-line description\>

## Scope Boundaries

### In scope

- Changes to `src/agents/reviewer.md` (rules, skills, responsibilities)
- Changes to `src/skills/workflow/review_changeset/SKILL.md` (review checks, report template)
- Changes to other skills referenced by the reviewer agent
- Adding new skills if a review capability is entirely missing

### Out of scope

- Production code changes
- Changes to non-reviewer agents or skills
- Changes to files with "no-vcs" in the name

## MUST

- Read target files before proposing changes.
- Present each suggestion individually for approval.
- Preserve existing file structure and formatting conventions.
- Only propose changes that address actual gaps — do not add redundant checks.

## MUST NOT

- Apply changes without explicit approval.
- Modify production code.
- Remove existing review checks or weaken existing rules.
- Add checks that duplicate what's already covered.
