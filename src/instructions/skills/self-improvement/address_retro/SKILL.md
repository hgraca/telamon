---
name: telamon.address_retro
description: "Addresses retrospective findings by suggesting workflow improvements, asking for approval, and implementing approved changes. Use after a retrospective is completed or via /address-retro command."
---

# Skill: Address Retrospective

Turn retrospective findings into concrete workflow improvements. Parse a retro file, extract improvement items, propose changes to workflow/skill/agent files, get approval per suggestion, implement approved ones.

## When to Apply

- After the `telamon.retrospective` skill produces a retro file
- When the `/address-retro` command is invoked with a retro file path
- When the orchestrator identifies actionable improvements in a retrospective

## Input

A retro file path (`$1`). The file follows the `telamon.retrospective` template and contains at minimum a **What Needs Improvement** section with actionable items.

## Procedure

### Step 1: Parse the retro file

Read the retro file at the provided path. Extract all items from:

1. **What Needs Improvement** section — each bullet is a candidate improvement. Items with an `**Action**:` annotation are highest priority.
2. **Process Observations** section — look for patterns that suggest systemic issues (high re-delegations, review iterations, escalations, blockers).
3. **Follow-Up Tasks** section — any items that describe process or workflow changes (not feature work).

Ignore items that are about specific code changes, bugs, or feature work — those belong in a backlog, not workflow improvements.

### Step 2: Analyze and propose

For each extracted improvement:

1. **Identify target files** — determine which skill, agent, or workflow file(s) need changes. Common targets:
   - `src/instructions/skills/workflow/*.md` — workflow skills
   - `src/instructions/skills/dev/**/*.md` — development convention skills
   - `src/instructions/skills/memory/**/*.md` — memory management skills
   - `src/instructions/agents/*.md` — agent role definitions
   - `src/instructions/commands/*.md` — command definitions
   - `.ai/telamon/memory/bootstrap/*.md` — bootstrap files

2. **Read target files** — understand current content before proposing changes.

3. **Draft a concrete suggestion** — specify:
   - What file to change
   - What section to modify (quote existing text)
   - What the new text should be
   - Why this change addresses the retro finding

### Step 3: Present suggestions for approval

Present each suggestion to the human stakeholder in this format:

> ### Suggestion N: \<title\>
>
> **Retro finding**: \<quote from the retro file\>
>
> **Target file**: \<path\>
>
> **Change**: \<description of the change\>
>
> **Rationale**: \<why this addresses the finding\>

Ask for approval of each suggestion individually. Options:
- **Approve** — implement as proposed
- **Modify** — implement with requested changes
- **Skip** — do not implement this suggestion

### Step 4: Implement approved suggestions

For each approved suggestion:

1. Apply the change to the target file(s).
2. If the change affects a skill referenced by agent roles, verify the reference is still valid.
3. Record the change as a decision using the `telamon.remember_lessons_learned` skill.
4. **Commit the changeset** — use `git add <specific-files>` (never `git add -A` or `git add .`), verify `git diff --staged --stat`, then commit with a descriptive message.

### Step 5: Summary

Output a summary to the human stakeholder:

> ### Address Retro Summary
>
> **Retro file**: \<path\>
> **Suggestions proposed**: N
> **Approved**: N
> **Skipped**: N
> **Modified**: N
>
> #### Changes applied
>
> - \<file\>: \<one-line description\>

## Scope Boundaries

### In scope

- Changes to workflow skills, agent definitions, command definitions, bootstrap files, memory management skills, and development convention skills.
- Adding new rules, constraints, steps, or guardrails to existing workflows.
- Reordering steps, adding checklists, or tightening acceptance criteria.
- Adding new skills if the retro reveals a missing workflow capability.

### Out of scope

- Production code changes — those go in a backlog, not workflow improvements.
- Changes to MCP server configuration or Docker infrastructure.
- Changes to files with "no-vcs" in the name.

## MUST

- Read target files before proposing changes — never suggest blind edits.
- Present each suggestion individually — never batch-approve.
- Preserve existing skill structure and formatting conventions (YAML frontmatter, heading hierarchy, table formatting).
- Record all approved changes as decisions.

## MUST NOT

- Apply changes without explicit approval.
- Modify production code — this skill is for meta/workflow improvements only.
- Remove existing constraints or guardrails without strong justification.
- Create duplicate skills when an existing skill can be extended.
