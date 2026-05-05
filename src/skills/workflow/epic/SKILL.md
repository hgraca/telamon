---
name: telamon.epic
description: "Breaks an epic into stories, plans each story, then implements each story sequentially. Use when a human stakeholder provides a large initiative spanning multiple stories or bounded contexts."
---

# Skill: Epic

Break an epic into stories, plan each story, then implement each story.

## When to Apply

- When a human stakeholder provides a large initiative spanning multiple stories or bounded contexts
- When the `/epic` command is invoked
- When request classification identifies work type as **Epic** and size as **Large**

## Artifacts

Place all artifacts under a single `<epic-folder>` in `.ai/telamon/memory/work/active/`. Each story gets a sub-folder within the epic folder. Artifacts must not be committed to git.

### Folder structure

```
.ai/telamon/memory/work/active/YYYYMMDD-HHMMSS-NN-<epic_slug>/
  backlog.md                          # Epic-level backlog (stories, not tasks)
  summary.md                          # Epic planning summary
  YYYYMMDD-HHMMSS-NN-<story_slug>/    # One sub-folder per story
    backlog.md                        # Story-level backlog (tasks)
    PLAN-ARCH-YYYY-MM-DD-NNN.md       # Combined architecture spec + implementation plan
    summary.md                        # Story planning summary
    ...
```

`YYYYMMDD-HHMMSS` is the current UTC timestamp. `NN` is a zero-padded sequential number. Check existing folders in `.ai/telamon/memory/work/active/` and use the next available number. The timestamp prefix provides chronological ordering; the sequential number disambiguates folders created in the same second.

### One folder per initiative — MUST

Each epic MUST have exactly one folder. NEVER create a second folder for the same initiative. If an existing folder matches the current epic (by slug or topic), reuse it.

### Scratch files

When you need to create a temporary file, use the `telamon.thinking` skill. Promote useful findings to brain files before closing the session.

## Procedure

### Step 0: Pre-flight

1. Read brain/ notes per the `telamon.recall_memories` skill. Identify entries relevant to the current scope. Include applicable lessons in all delegations.
2. **Check for existing epic folder**: List `.ai/telamon/memory/work/active/` and look for a folder that matches the current epic. If one exists, reuse it — do NOT create a new folder.

### Step 1: Create epic backlog

Delegate to @po to break the epic into stories and create `<epic-folder>/backlog.md`.

- Each entry in the epic backlog is a **story** (not a task). Stories should be independently plannable and implementable.
- PO must include for each story: title, description, priority, dependencies on other stories, and high-level acceptance criteria.
- PO saves to `<epic-folder>/backlog.md`, signals FINISHED with the backlog.
- If the PO signals NEEDS_INPUT, relay the question to the human stakeholder and re-delegate with the answer.

### Step 2: Plan all stories

For each story in the epic backlog, in priority order:

1. Create the story sub-folder: `<epic-folder>/YYYYMMDD-HHMMSS-NN-<story_slug>/`
2. Follow the `telamon.plan_story` skill to produce the story plan. Use the story sub-folder as the `<issue-folder>`.
3. Output a planning progress report to the human stakeholder after each story:
   > **Epic planning progress**: \<planned\>/\<total\> stories planned | \<remaining\> remaining

All stories MUST be planned before implementation begins. This ensures cross-story dependencies and architectural concerns are visible before any code is written.

### Step 3: Epic-level architecture review

After all stories are planned, review the combined scope for cross-cutting concerns:

1. Delegate to @architect to review the full epic — all story backlogs and architecture specs together.
2. The architect should identify: shared abstractions, migration ordering, cross-story dependencies, and integration risks.
3. If the architect recommends changes, update the affected story plans before proceeding.

### Step 4: Implement stories

For each story in the epic backlog, in dependency-respecting order:

1. Follow the `telamon.implement_story` skill for the story. Use the story sub-folder as the `<issue-folder>`.
2. Output an implementation progress report to the human stakeholder after each story:
   > **Epic implementation progress**: \<implemented\>/\<total\> stories done | \<blocked\> blocked | \<remaining\> remaining
3. If a story's implementation reveals a problem that affects later stories, pause and re-plan the affected stories before continuing.

### Step 5: Completion

When all stories are implemented:

1. Run the full test suite to verify cross-story integration.
2. Produce a post-epic retrospective using the `telamon.retrospective` skill. Save to `<epic-folder>/retrospective.md`.
3. Address retrospective findings using the `telamon.address_retro` skill — pass the retro file path.
4. Notify human stakeholder with a completion report covering all stories and recommended next actions.
5. Follow the `telamon.remember_task` skill to capture lessons learned from the epic.
6. Archive the epic folder: move `<epic-folder>` from `.ai/telamon/memory/work/active/` to `.ai/telamon/memory/work/archive/`, preserving its name.

## Story Ordering

- Respect explicit dependencies declared in the epic backlog.
- When no dependencies exist, implement stories in priority order.
- Foundation stories (shared domain models, infrastructure, configuration) come before stories that consume them.
- Stories that modify the same bounded context should be implemented sequentially.

## Exception Handling

- When an unexpected situation arises, use the `telamon.exception-handling` skill for structured recovery.
- If a story cannot be planned or implemented due to a dependency on an unfinished story, mark it BLOCKED in the epic backlog and continue with the next eligible story.
- The orchestrator may terminate early if requirements change, the epic is deprioritized, or the human stakeholder requests a pivot.
- If the epic scope grows during planning, pause and ask the human stakeholder whether to expand the epic or split off new stories.
