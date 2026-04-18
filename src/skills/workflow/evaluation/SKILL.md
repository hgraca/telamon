---
name: telamon.evaluation
description: "Evaluates quality of completed work and runs post-iteration retrospectives. Use after completing a task or iteration to assess quality, capture metrics, and identify process improvements."
---

# Skill: Evaluation and Monitoring

Structured quality evaluation of completed work and post-iteration retrospectives. Ensures that quality is assessed systematically, not just through "tests pass and reviewer approved."

## When to Apply

- After completing an implementation task (post-task evaluation)
- After completing all tasks in a backlog (post-iteration retrospective)
- When the PO needs to assess whether delivered work meets quality standards

## Post-Task Quality Rubric

After each task is implemented, reviewed, and committed, the PO evaluates it against this rubric:

| Dimension | Question | Rating |
|---|---|---|
| **Plan Adherence** | Does the implementation match what the Architect's plan specified? | FULL / PARTIAL / DEVIATED |
| **Acceptance Criteria** | Are all acceptance criteria met and tested? | ALL / SOME / NONE |
| **Test Coverage** | Are happy paths, failure paths, and edge cases covered? | COMPLETE / ADEQUATE / GAPS |
| **Code Quality** | Does the code follow project conventions and pass static analysis? | CLEAN / MINOR_ISSUES / SIGNIFICANT_ISSUES |
| **Documentation** | Are new patterns, configs, or APIs documented where needed? | COMPLETE / PARTIAL / MISSING |

### Quick Rating

- **All FULL/ALL/COMPLETE/CLEAN** = task delivered cleanly, no follow-up needed.
- **Any PARTIAL/ADEQUATE/MINOR_ISSUES** = acceptable but note for improvement in memories.md.
- **Any DEVIATED/NONE/GAPS/SIGNIFICANT_ISSUES/MISSING** = follow-up task required before moving on.

## Post-Iteration Retrospective

After all tasks in a backlog are completed (`telamon.workflow.implement-story` skill step 3), the PO produces a retrospective:

### Template

Save to `<issue-folder>/RETRO-YYYY-MM-DD.md`.

> # Retrospective
>
> **Iteration**: <issue-folder name>
> **Date**: YYYY-MM-DD
> **Tasks completed**: N / M
>
> ## Quality Summary
>
> | Task | Plan Adherence | Acceptance Criteria | Test Coverage | Code Quality | Documentation |
> |---|---|---|---|---|---|
> | Task 1 | FULL | ALL | COMPLETE | CLEAN | COMPLETE |
> | Task 2 | ... | ... | ... | ... | ... |
>
> ## What Went Well
>
> - <thing that worked>
>
> ## What Needs Improvement
>
> - <thing that could be better>
> - **Action**: <concrete change to make> — record in memories.md under the appropriate category.
>
> ## Process Observations
>
> - **Re-delegations**: How many times was work re-delegated due to stalled sessions?
> - **Review iterations**: Average number of Reviewer -> Developer round-trips per task.
> - **Escalations**: How many escalations occurred and to whom?
> - **Blockers**: What blocked progress and how was it resolved?
>
> ## Follow-Up Tasks
>
> _If none: "No follow-up tasks."_
>
> - <follow-up task description>

## Monitoring During Implementation

The PO should track these signals during implementation (no formal report needed — just awareness):

- **Iteration velocity** — Are later tasks taking longer than earlier ones? May indicate context overflow or growing complexity.
- **Review rejection rate** — Are most reviews requesting changes? May indicate unclear plans or insufficient delegation context.
- **Test failure rate** — Are developers spending most time fixing tests rather than implementing? May indicate tests were written with incorrect assumptions.
- **Escalation frequency** — Are agents frequently escalating? May indicate plans need more detail.

If any signal trends negatively across 3+ tasks, the PO should pause and address the root cause before continuing.
