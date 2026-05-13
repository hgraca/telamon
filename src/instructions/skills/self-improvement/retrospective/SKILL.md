---
name: telamon.retrospective
description: "Evaluates quality of completed work and runs post-iteration retrospectives. Use after completing a task or iteration to assess quality, capture metrics, and identify process improvements."
---

# Skill: Evaluation and Monitoring

Structured quality evaluation of completed work and post-iteration retrospectives. Ensures that quality is assessed systematically, not just through "tests pass and reviewer approved."

## When to Apply

- After completing an implementation task (post-task evaluation)
- After completing all tasks in a backlog (post-iteration retrospective)
- When the orchestrator needs to assess whether delivered work meets quality standards

## Honesty gate (MUST)

Every claim in the retrospective about a deliverable, agent action, or workflow event MUST cite either:

1. **The artefact's path AND a verifying observation** (line number, content excerpt) the author obtained via `read`, OR
2. **The absence of an expected artefact**, confirmed via `glob` or `ls` (cite the empty-result tool call).

The retrospective MUST NOT make causal claims about subagent behaviour ("the critic hallucinated", "the architect skipped X", "the PO over-scoped Y") without citing the artefact that demonstrates the behaviour. If a behaviour is asserted to be missing, the assertion MUST cite a tool call (`grep`, `glob`, `read`) whose result is consistent with the absence claim.

**Format requirement**: each "what went wrong" claim in the retrospective MUST include a parenthetical citation in the form `(per <path>:<line> | per <tool-call-result>)`. Example:

> "Architect skipped the Pre-FINISHED Hygiene Gate (per `interactions.md:42` showing FINISHED signal without prior hygiene-report file; per `glob 'storage/.../iteration-N/.ai/.../hygiene-*.md'` returning no matches)."

**Validation**: a retrospective entry without supporting citation is invalid. The retrospective author (orchestrator) MUST either support the claim with a citation or remove it before filing the retrospective. The orchestrator MUST NOT defer this check to a later iteration's quality-report — the gate fires at retrospective-write time.

### Per-Agent count claims (MUST)

Every "total invocations" or per-agent count claim in the retrospective MUST cite the source of the count: either `(per interactions.md Per-Agent Totals table)` or `(per delegation_count: X PO + Y architect + ...)` with the underlying counts from `interactions.md`. Counts not citing source-of-truth are invalid. The retrospective author MUST run the Per-Agent reconciliation procedure (per `plan` SKILL Step 8 `Per-Agent Totals reconciliation across all closing artefacts`) before writing any agent-count claim.

**Prose-vs-table cross-check (MUST)**: Every numeric claim in retrospective free-prose (paragraphs, bullets, "What Went Well" / "What Needs Improvement" / "Process Observations") about an agent count, invocation count, stall count, critic-round count, re-delegation count, or task count MUST match the corresponding cell in the reconciliation table or be flagged with an inline `[reconciliation-note: <one-line rationale>]` tag explaining the discrepancy (e.g. `[reconciliation-note: prose excludes the rejected critic R1 first attempt; table includes it per Per-Agent Totals procedure]`).

The retrospective author MUST run a prose-vs-table cross-check before filing the retrospective: for each numeric claim in free-prose that names a count category (agent, invocation, stall, critic-round, re-delegation, task), look up the same category in the reconciliation table and confirm the values match (or that an inline `[reconciliation-note:]` tag explains the divergence). Counts in free-prose without either match or tag are invalid.

**Validation**: a retrospective with prose count `K` and table count `K' ≠ K` for the same category, without a `[reconciliation-note:]` tag bridging the two, is invalid. Either the prose number must be corrected to match the table, or the divergence must be explained inline. The orchestrator MUST NOT defer this check to a later iteration's quality-report — the gate fires at retrospective-write time.

## Post-Task Quality Rubric

After each task is implemented, reviewed, and committed, the orchestrator evaluates it against this rubric:

| Dimension               | Question                                                           | Rating                                    |
|-------------------------|--------------------------------------------------------------------|-------------------------------------------|
| **Plan Adherence**      | Does the implementation match what the Architect's plan specified? | FULL / PARTIAL / DEVIATED                 |
| **Acceptance Criteria** | Are all acceptance criteria met and tested?                        | ALL / SOME / NONE                         |
| **Test Coverage**       | Are happy paths, failure paths, and edge cases covered?            | COMPLETE / ADEQUATE / GAPS                |
| **Code Quality**        | Does the code follow project conventions and pass static analysis? | CLEAN / MINOR_ISSUES / SIGNIFICANT_ISSUES |
| **Documentation**       | Are new patterns, configs, or APIs documented where needed?        | COMPLETE / PARTIAL / MISSING              |

### Quick Rating

- **All FULL/ALL/COMPLETE/CLEAN** = task delivered cleanly, no follow-up needed.
- **Any PARTIAL/ADEQUATE/MINOR_ISSUES** = acceptable but note for improvement in memories.md.
- **Any DEVIATED/NONE/GAPS/SIGNIFICANT_ISSUES/MISSING** = follow-up task required before moving on.

## Post-Iteration Retrospective

After all tasks in a backlog are completed (`telamon.implement_story` skill step 3), the orchestrator produces a retrospective:

### Template

Save to `<issue-folder>/RETRO-YYYY-MM-DD.md`. After writing, run `format-md` on the file to align table columns.

> # Retrospective
>
> **Iteration**: <issue-folder name>
> **Date**: YYYY-MM-DD
> **Tasks completed**: N / M
>
> ## Quality Summary
>
> | Task   | Plan Adherence | Acceptance Criteria | Test Coverage | Code Quality | Documentation |
> |--------|----------------|---------------------|---------------|--------------|---------------|
> | Task 1 | FULL           | ALL                 | COMPLETE      | CLEAN        | COMPLETE      |
> | Task 2 | ...            | ...                 | ...           | ...          | ...           |
>
> ## What Went Well
>
> - <thing-that-worked>
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

The orchestrator should track these signals during implementation (no formal report needed — just awareness):

- **Iteration velocity** — Are later tasks taking longer than earlier ones? May indicate context overflow or growing complexity.
- **Review rejection rate** — Are most reviews requesting changes? May indicate unclear plans or insufficient delegation context.
- **Test failure rate** — Are developers spending most time fixing tests rather than implementing? May indicate tests were written with incorrect assumptions.
- **Escalation frequency** — Are agents frequently escalating? May indicate plans need more detail.

If any signal trends negatively across 3+ tasks, the orchestrator should pause and address the root cause before continuing.

## MUST

- After producing a retrospective, immediately invoke the `telamon.address_retro` skill with the retro file path as input. Do not defer to a later session or skip this step.
- The `address_retro` skill must process all three retro sections: **What Needs Improvement**, **Process Observations**, and **Follow-Up Tasks**. Explicitly acknowledge each section — even if no actionable items exist, state "No actionable items" rather than silently skipping.
