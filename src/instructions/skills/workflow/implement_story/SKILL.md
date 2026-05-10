---
name: telamon.implement_story
description: "Implements an approved plan by orchestrating Tester, Developer, and Reviewer in a structured cycle per task. Use after the human stakeholder approves the plan from the telamon.plan_story skill."
---

# Skill: Implement Plan

Implement an approved plan by orchestrating Tester, Developer, and Reviewer for each task in the backlog.

## When to Apply

- After the human stakeholder approves the plan from the `telamon.plan_story` skill
- When the `/implement`, `/story`, or `/epic` command is invoked for implementation
- When the `/test`, `/dev`, or `/review` command invokes a specific step

## Artifacts

Place all artifacts in the `<issue-folder>` established during planning (see `telamon.plan_story` skill for naming conventions). Artifacts must not be committed to git.

### Scratch files

When you need to create a temporary file, use the `telamon.thinking` skill. Promote useful findings to brain files before closing the session.

### Pre-flight check

Before creating any artifact, verify the issue folder already exists in `.ai/telamon/memory/work/active/`. If it does not, STOP — planning must be completed first via `telamon.plan_story`. If multiple folders exist for the same initiative, consolidate into the correctly-named one and delete the duplicate.

## Clarification Channels

If the developer needs:
- Specification clarification: consult the product owner (via the orchestrator)
- Technical guidance: ask the architect first; if inconclusive, ask the human stakeholder

## Procedure

### Step 0: Pre-flight

Read brain/ notes per the `telamon.recall_memories` skill. Identify entries relevant to the current scope. Include applicable lessons in delegations to Developer, Tester, and Reviewer.

### Step 1: Provide the plan

Provide the plan (`backlog.md` and any architecture/UI specifications) to @developer.

### Step 2: Task cycle

For each task in the backlog:

1. **Test** — Delegate to @tester:
   - Create a test for each acceptance criterion
   - Create additional automated tests deemed necessary
   - When tests involve parsing structured text (frontmatter, markdown, YAML, config files), always include edge cases: valid input, missing/absent structure, and malformed structure (e.g., test with frontmatter, without frontmatter, and with malformed frontmatter).
   - For infrastructure tasks (shell scripts, YAML configs, markdown) where unit tests don't apply, create a simple integration test (e.g., `test-init.sh` pattern) that validates the install/init/doctor chain programmatically. If no integration test is feasible, document why in the session report.
   - Save session report to task folder, signal FINISHED with report

2. **Implement** — When Tester is finished, delegate to @developer:
   - Implement the task following the plan
   - Ensure tests pass before considering the task complete
   - **Commit the changeset** before signalling FINISHED — use `git add <specific-files>` (never `git add -A` or `git add .`), verify `git diff --staged --stat`, then commit with a clear message
   - If the task introduces a new user-facing feature (plugin, tool, command, skill), create a documentation page even if the task description doesn't explicitly require it. Follow existing doc structure in `docs/`.
   - Signal FINISHED

3. **Review** — When Developer is finished, delegate to @reviewer:
   - Save Review Report to task folder, signal FINISHED

4. **Address findings** — When Reviewer is finished, delegate to @developer to address issues. Developer must commit fixes before signalling FINISHED. After fixes are committed, create an architecture spec addendum file referring the differences from the architecture spec plan to the actual final implementation. Iterate from step 2.3 until no remaining issues.

5. **Mark done** — Set task title in _strikethrough_ in `backlog.md`.

6. **Progress report** — Output to human stakeholder:
   > **Progress**: \<completed\>/\<total\> tasks done | \<blocked\> blocked | \<remaining\> remaining

7. **Capture lessons** — When a task is complete, follow the `telamon.remember_task` skill immediately. Do not defer to end of session.

8. Move to the next task from step 2.1.

### Step 3: Completion

When all tasks are done:

1. Verify test coverage has not regressed. If it has, create a follow-up task before approval.
2. Produce a post-iteration retrospective using the `telamon.retrospective` skill.
3. Address retrospective findings using the `telamon.address_retro` skill — pass the retro file path.
4. Approve or reject.
5. When all tasks are done, follow the `telamon.remember_task` skill to capture lessons learned.
6. Notify human stakeholder with completion report and recommended next actions.
7. Archive the issue folder: move the `<issue-folder>` from `.ai/telamon/memory/work/active/` to `.ai/telamon/memory/work/archive/`, preserving its name.
8. Proceed with non-destructive closure actions immediately without asking permission.

## Delegation Rules

- Invoke Tester, Developer, and Reviewer as separate subagents — never merge into a single delegation.
- Limit each developer delegation to at most 3 tasks.
- Include concrete class signatures, constructor parameters, file paths, and dependency details from the existing codebase.
- Include only context relevant to the specific task — not the entire project context. Summarize large files. Load one skill per delegation.
- All code changes — including trivial review fixes — must be delegated to the Developer. The orchestrator must never apply code changes directly.
- When delegating plugins or JS/TS code, state the project's import conventions explicitly (e.g., "Use bare `fs`/`path` imports, not `node:fs`/`node:path`"). Reference existing plugin files as style examples.
- When delegating code that loops over filesystem operations (readFileSync, writeFileSync, readdirSync), explicitly require: "Wrap filesystem operations in try/catch — a single failure must not abort the entire loop." Point to reference implementations that demonstrate this pattern.

## Exception Handling

- When an unexpected situation arises, use the `telamon.exception-handling` skill for structured recovery.
- If a developer session stalls or produces no usable output:
  1. Inspect working directory for partial progress
  2. Re-delegate only incomplete work to a fresh session with explicit specifications (concrete class signatures, constructor parameters, test file locations)
  3. Never re-delegate already-completed work
- The orchestrator may terminate early if requirements change or task is deprioritized.

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
3. Each parallel track follows the full task cycle (step 2.1–2.4) independently.
4. After all parallel tracks complete, run the full test suite to verify no integration conflicts.
5. If conflicts arise, create a follow-up task to resolve them sequentially.

### When NOT to Parallelize

- Tasks that modify the same bounded context's domain layer
- Tasks where one introduces a new abstraction that the other consumes
- Database migrations (always sequential to avoid ordering issues)
- Tasks where the Architect's plan specifies an explicit ordering

## MUST

- Run the retrospective (Step 3.2) in the same session as the final commit — do not defer to a later session.
