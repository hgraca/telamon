---
---
name: telamon.execute_plan
description: "Executes implementation plan steps systematically. Use when implementing an architect's plan step-by-step, signalling completion, and handling review feedback."
---

# Skill: Plan Execution

Systematic process for implementing an architect's plan one step at a time, signalling completion, and responding to review feedback.

## When to Apply

- When implementing an architect's plan into production code
- When a plan has reached FINAL status and is ready for implementation

## Step Completion Protocol

Complete the plan one step at a time:

1. **Find precedent** — Before writing new code, find and follow the closest existing implementation.
2. **Implement** — Write the code specified in the plan step.
3. **Test** — Run the test suite. Fix failures introduced by this step before moving on.
4. **Format** — Run the project's formatter (e.g. `make cs` / `vendor/bin/php-cs-fixer fix`) for any source files touched in this step. Stage any formatter corrections together with the step's changes — they belong in the same commit, not orphaned in the working tree for someone else to discover.
5. **Commit** — Only after tests pass and the formatter output is clean. Use `git add <specific-files>` (never `git add -A` or `git add .` from repository root), verify `git diff --staged --stat`, then commit referencing the task and step (e.g. `[TASK-123] Step 3: Add CreateOrder command handler`). **A task is not finished until it is committed.**

If a step fails in a way suggesting the plan is wrong (not a coding mistake), do not redesign. Escalate.

## Signalling Completion

When all steps are implemented and tests pass:

1. Record a brief summary in `<issue-folder>/DONE.md`: steps completed, test suite result, open questions or caveats.
2. This signals the Reviewer that the task is ready for review.

## Handling Review Feedback

- **BLOCKER**: Must fix. Implement fix, re-run tests, commit, update `DONE.md`.
- **WARNING**: Should fix. Same process, unless you believe the finding is incorrect — respond using `Question:` / `Answer:` / `Rationale:` format.
- **INFO**: Consider fixing. No response required if you choose not to act.

After addressing feedback, update `DONE.md` to signal re-review readiness.
