---
name: telamon.review_plan
description: "Reviews an architect's implementation plan for correctness, completeness, and architectural consistency. Use when evaluating a draft plan before code is written."
---

# Skill: Plan Review

Evaluate an architect's implementation plan for correctness, completeness, and architectural consistency before any code is written.

## When to Apply

- When the Architect sends a draft plan for review
- When evaluating whether a plan is ready for implementation

## Inputs

- Architect's plan
- The brief
- Architecture document
- ADR log

## Plan Review Report

### Mandatory output filename — MUST

Save the review to `<issue-folder>/PLAN-REVIEW-YYYY-MM-DD-NNN.md` where:

- `YYYY-MM-DD` is the current UTC date.
- `NNN` is a zero-padded 3-digit sequential number, scoped to the same issue folder. List existing `PLAN-REVIEW-*.md` files in the folder and use the next available number; start at `001`.

Do **not** use any other prefix (no `CRITIC-*.md`, no `REVIEW-*.md`, no `critic-feedback.md`). The orchestrator and downstream tooling locate review files by the `PLAN-REVIEW-` prefix; deviating breaks `recall_active_task` and the architect's "address feedback" loop.

If a previous review with the same date+number already exists, do not overwrite it — bump `NNN`. Each iteration of the critic loop produces a new file.

### Template

> # Plan Review Report
>
> **Verdict**: APPROVED | CHANGES REQUESTED
>
> A plan is APPROVED when it contains zero BLOCKER findings.
>
> ## Strengths
>
> What works well. Reference step numbers and design choices.
>
> ## Findings
>
> _If none: "No findings. Plan is sound."_
>
> ### Findings summary
> |#| Title                  |Location| Severity                      |
> |---|------------------------|---|-------------------------------|
> |<NN>| <one_line_description> |<where_in_the_plan>| <BLOCKER,WEAKNESS,SUGGESTION> |
>
> ### Finding <n>: <Title>
> - **Category**: Weakness | Suggestion | Blocker
> - **Severity**: CRITICAL | IMPORTANT | MINOR
> - **Evidence**: File paths, line numbers, or plan step references.
> - **Problem found**:
> - **Why it matters**:
> - **Recommendation**:

### Category and Severity

- **Blocker** — Always CRITICAL. Must resolve before approval.
- **Weakness** — CRITICAL or IMPORTANT. Concrete problem that will cause issues.
- **Suggestion** — IMPORTANT or MINOR. Improvement opportunity.

When in doubt between severities, choose the higher one.
