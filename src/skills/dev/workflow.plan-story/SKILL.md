---
name: telamon.workflow.plan-story
description: "Plans a user story by producing a backlog, architecture specification, and optional UI/UX specification. Use when a human stakeholder provides a story, feature request, or business initiative that needs planning before implementation."
---

# Skill: Plan Story

Produce a plan for a user story composed of:
- Issue backlog in `backlog.md` — clear, small, prioritized issues with requirements and acceptance criteria
- Architecture specification (if necessary)
- UI/UX specification (if necessary)

## When to Apply

- When a human stakeholder provides a story, feature request, or business initiative
- When the `/plan` or `/story` command is invoked
- When an epic is broken into stories that each need planning

## Artifacts

Place all artifacts in a single `<issue-folder>` under `.ai/issue/`. Planning artifacts must not be committed to git.

### Scratch files

Any ephemeral notes, drafts, or intermediate thinking produced during planning must be saved to `<proj>/.ai/telamon/memory/thinking/`. Promote any useful findings from `thinking/` to the appropriate brain file or issue artifact before closing the session. Delete scratch files that add no lasting value.

### Folder naming

`.ai/issue/NN-<title_slug>/`

`NN` is a zero-padded sequential number. Check existing folders in `.ai/issue/` and use the next available number.

### One folder per initiative — MUST

Each epic or story MUST have exactly one folder. NEVER create a second folder for the same initiative. Sub-story artifacts within an epic go in sub-folders of the epic folder (e.g., `.ai/issue/01-helm-migration/03-openbao/`).

## Procedure

### Step 0: Pre-flight

1. Read `.ai/telamon/memory/brain/memories.md` (if it exists). Identify entries relevant to the current scope. Include applicable lessons in all delegations.
2. **Check for existing issue folder**: List `.ai/issue/` and look for a folder that matches the current initiative (by slug or topic). If one exists, reuse it — do NOT create a new folder. If multiple folders exist for the same initiative, consolidate into the correctly-named one and delete the duplicate.

### Step 1: Create backlog

Create `<issue-folder>/backlog.md` with prioritized tasks, requirements, and acceptance criteria.

Apply the backlog rules below when writing tasks.

### Step 2: Architecture review

Delegate to @architect to review the backlog and add architecture guidelines.

- Architect must produce a concrete directory tree mapping every source file to an assigned path.
- Architecture details go in a separate specification only if necessary — not inline in the backlog.
- Architect saves to `<issue-folder>/ARCH-YYYY-MM-DD-NNN.md`, signals FINISHED with the report.

### Step 3: UI/UX review (if applicable)

If UI work is needed, delegate to @ui-designer and/or @ux-designer to review the backlog.

- UI Designer saves to `<issue-folder>/UI-YYYY-MM-DD-NNN.md`, signals FINISHED with report.
- UX Designer saves to `<issue-folder>/UX-YYYY-MM-DD-NNN.md`, signals FINISHED with report.

Skip this step if the story has no UI component.

### Step 4: Critic review loop

Delegate to @critic for feedback on all documents produced so far.

- Critic saves to `<issue-folder>/CRITIC-YYYY-MM-DD-NNN.md`.
- Address issues deemed necessary.
- Justify issues that will not be addressed.
- Terminate the loop if progress stalls or goals shift — ask human stakeholder for direction.
- Iterate from step 3 until no remaining issues to address.

### Step 5: Planning summary and approval

Create `<issue-folder>/summary.md` by following the `telamon.plan-summary` skill.

Output the summary to the human stakeholder and ask for final approval.

### Step 6: Transition

On approval, proceed to implementation using the `telamon.workflow.implement-story` skill.

## Backlog Rules

- Known bugs discovered during planning must have PO cost/benefit evaluation before being marked out of scope. Justify why incorrect output is acceptable, or include the bug in the backlog.
- When an issue requires sorting a collection, specify the sort key and justify why it matches the algorithm's invariant.
- When a use case returns data to presentation, specify an application-layer DTO — name the class and fields. Domain entities must not cross the application-to-presentation boundary.
- For refactoring issues, include an acceptance criterion: "The refactored code must produce byte-identical output to the original for the same input."
- When an issue involves building URLs from user-supplied or external input, include an acceptance criterion requiring URL encoding on interpolated segments.
- When the project has a `composer.json`, include an Issue 0 acceptance criterion verifying the package name follows `vendor/package-name` format (lowercase, hyphens only).

## Post-Planning

Document lessons learned in `.ai/telamon/memory/brain/memories.md` using the `telamon.memory-management` skill:
- Reusable questions and answers from interactions with Architect, Critic, and human stakeholder
- Architecture decisions clarified during planning
- Domain knowledge uncovered during requirements refinement
