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

Do **not** use any other prefix (no `CRITIC-*.md`, no `REVIEW-*.md`, no `critic-feedback.md`). The orchestrator and downstream tooling locate review files by the `PLAN-REVIEW-` prefix; deviating breaks task-resumption flows and the architect's "address feedback" loop.

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
> - **Workflow gap** _(optional)_: If this finding represents a *class* of failure not prevented by the workflow (cross-artefact drift, recurring type leak, repeated rule violation across artefacts, same defect category across multiple findings in this review), name the rule that should exist and which file should host it. Leave blank if the finding is a one-off.

### Category and Severity

- **Blocker** — Always CRITICAL. Must resolve before approval.
- **Weakness** — CRITICAL or IMPORTANT. Concrete problem that will cause issues.
- **Suggestion** — IMPORTANT or MINOR. Improvement opportunity.

When in doubt between severities, choose the higher one.

### Third-party library citation in recommendations — MUST

When a recommendation involves a third-party library — namespace, class name, method signature, configuration option — the critic MUST cite the source-of-truth for the API in the recommendation itself. Acceptable cites are the same as in `telamon.plan_implementation` SKILL's "Third-party library integration" section:

- the library's `composer.json` autoload section with file path + line reference, OR
- a specific class file in the vendor tree with file path + class name, OR
- the library's official README or documentation URL with the symbol name visible at that URL.

Hypothetical recommendations are forbidden — if you cannot verify the API surface, the finding should describe the problem and require the architect to verify, NOT propose a specific replacement (e.g., "the cited namespace is unverified — architect must verify against vendor's `composer.json` before re-submission" rather than "use `Approve\Approvals` instead").

This rule is symmetric with the architect-side rule in `telamon.plan_implementation` SKILL. Together they form a closed loop: architect must cite when proposing; critic must cite when recommending.
