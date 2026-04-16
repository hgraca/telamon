---
name: telamon.workflow.implement-story
description: "Implements an approved plan by orchestrating Tester, Developer, and Reviewer in a structured cycle per task. Use after the human stakeholder approves the plan from the telamon.workflow.plan-story skill."
---

# Skill: Implement Plan

Implement an approved plan by orchestrating Tester, Developer, and Reviewer for each task in the backlog.

## When to Apply

- After the human stakeholder approves the plan from the `telamon.workflow.plan-story` skill
- When the `/implement`, `/story`, or `/epic` command is invoked for implementation
- When the `/test`, `/dev`, or `/review` command invokes a specific step

## Artifacts

Place all artifacts in the `<issue-folder>` established during planning (see `telamon.workflow.plan-story` skill for naming conventions). Artifacts must not be committed to git.

### Scratch files

Any ephemeral notes, drafts, or intermediate thinking produced during implementation must be saved to `<proj>/.ai/telamon/memory/thinking/`. Promote useful findings to brain files before closing the session. Delete scratch files that add no lasting value.

### Pre-flight check

Before creating any artifact, verify the issue folder already exists in `.ai/issue/`. If it does not, STOP — planning must be completed first via `telamon.workflow.plan-story`. If multiple folders exist for the same initiative, consolidate into the correctly-named one and delete the duplicate.

## Clarification Channels

If the developer needs:
- Specification clarification: ask the PO
- Technical guidance: ask the architect first; if inconclusive, ask the human stakeholder

## Procedure

### Step 0: Pre-flight

Read `.ai/telamon/memory/brain/memories.md` (if it exists). Identify entries relevant to the current scope. Include applicable lessons in delegations to Developer, Tester, and Reviewer.

### Step 1: Provide the plan

Provide the plan (`backlog.md` and any architecture/UI specifications) to @developer.

### Step 2: Task cycle

For each task in the backlog:

1. **Test** — Delegate to @tester:
   - Create a test for each acceptance criterion
   - Create additional automated tests deemed necessary
   - Save session report to task folder, signal FINISHED with report

2. **Implement** — When Tester is finished, delegate to @developer:
   - Implement the task following the plan
   - Ensure tests pass before considering the task complete
   - Signal FINISHED

3. **Review** — When Developer is finished, delegate to @reviewer:
   - Save Review Report to task folder, signal FINISHED

4. **Address findings** — When Reviewer is finished, delegate to @developer to address issues. Iterate from step 2.3 until no remaining issues.

5. **Commit** — Developer creates one commit per task before starting the next:
   - Use `git add <specific-files>` — never `git add -A` or `git add .` from repository root
   - Verify `git diff --staged --stat` before committing

6. **Mark done** — Set task title in _strikethrough_ in `backlog.md`.

7. **Progress report** — Output to human stakeholder:
   > **Progress**: \<completed\>/\<total\> tasks done | \<blocked\> blocked | \<remaining\> remaining

8. **Capture lessons** — Append reusable patterns to `.ai/telamon/memory/brain/memories.md` immediately. Do not defer to end of session.

9. Move to the next task from step 2.1.

### Step 3: Completion

When all tasks are done:

1. Verify test coverage has not regressed. If it has, create a follow-up task before approval.
2. Produce a post-iteration retrospective using the `telamon.evaluation` skill.
3. Approve or reject.
4. Update `.ai/telamon/memory/brain/memories.md` with lessons learned using the `telamon.memory-management` skill.
5. Notify human stakeholder with completion report and recommended next actions.
6. Proceed with non-destructive closure actions immediately without asking permission.

## Delegation Rules

- Invoke Tester, Developer, and Reviewer as separate subagents — never merge into a single delegation.
- Limit each developer delegation to at most 3 tasks.
- Include concrete class signatures, constructor parameters, file paths, and dependency details from the existing codebase.
- Include only context relevant to the specific task — not the entire project context. Summarize large files. Load one skill per delegation.
- All code changes — including trivial review fixes — must be delegated to the Developer. PO must never apply code changes directly.

## Exception Handling

- When an unexpected situation arises, use the `telamon.exception-handling` skill for structured recovery.
- If a developer session stalls or produces no usable output:
  1. Inspect working directory for partial progress
  2. Re-delegate only incomplete work to a fresh session with explicit specifications (concrete class signatures, constructor parameters, test file locations)
  3. Never re-delegate already-completed work
- PO may terminate early if requirements change or task is deprioritized.

## Parallelization

By default, tasks execute sequentially (Tester -> Developer -> Reviewer per task). Run independent tasks in parallel only when **all** criteria are met:

### Eligibility

1. **No shared files** — Tasks do not modify the same files or directories.
2. **No dependency** — Neither task's output is the other task's input.
3. **No shared state** — Tasks do not modify the same database tables, configuration, or service registrations.
4. **Self-contained tests** — Each task's tests can run independently without the other task's code.

### How to Parallelize

1. Identify eligible parallel tasks from the backlog.
2. Delegate each task to a separate Developer session simultaneously, each with its own Tester and Reviewer cycle.
3. Each parallel track follows the full task cycle (step 2.1–2.5) independently.
4. After all parallel tracks complete, run the full test suite to verify no integration conflicts.
5. If conflicts arise, create a follow-up task to resolve them sequentially.

### When NOT to Parallelize

- Tasks that modify the same bounded context's domain layer
- Tasks where one introduces a new abstraction that the other consumes
- Database migrations (always sequential to avoid ordering issues)
- Tasks where the Architect's plan specifies an explicit ordering
