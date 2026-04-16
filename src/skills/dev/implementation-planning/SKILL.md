---
name: telamon.implementation-planning
description: "Creates implementation plans from a PO brief. Use when designing a technical plan that addresses all layers (domain, application, infrastructure, presentation, wiring, migrations, tests)."
---

# Skill: Implementation Planning

Create a detailed, step-by-step implementation plan from a PO's brief that a developer can follow without making design decisions.

## When to Apply

- When the PO provides an approved backlog and requests a technical plan
- When creating or revising an implementation plan for a feature or change

## Design Principles

Follow these principles when designing the plan:

- Analyze existing codebase patterns before proposing new ones. Prefer established conventions; document deviations in ADRs.
- Reference existing code as precedent. Legacy sections (defined in project-specific context files) must not be used as precedent.
- Specify Value Objects for domain concepts (names, IDs, scores, URLs, etc.).
- Port contracts must use typed DTOs — never raw arrays crossing boundaries.
- Port interfaces must not expose transport or infrastructure concepts.
- Application services returning data to presentation must return DTOs — never domain entities.
- Exceptions crossing layer boundaries must be defined at the port level.
- Design all event handlers and projections for idempotency.
- Every schema change needs a migration plan with rollback strategy.

## Plan Output

Save to `<issue-folder>/PLAN.md`.

### Plan Template

> # Implementation Plan
>
> **Brief**: Reference to the PO's brief or task ID.
> **Status**: DRAFT | IN REVIEW | FINAL
>
> ## Key Architect Decisions
> 
> |#| Decision | Rationale |
> |-|----------|-----------|
>
> ## Acceptance Criteria
>
> Restate the PO's acceptance criteria. Flag gaps or ambiguities back to the PO.
>
> ## Steps
>
> ### Steps summary
>
> | #  | Title        | Notes               |
> |----|--------------|---------------------|
> | NN | <step-title> | <step-notes-if-any> |
>
> ### Step <n>: <Title>
> - **Layer**: Domain | Application | Infrastructure | Presentation | Wiring | Migration | Test
> - **File path(s)**: Exact paths for files to create or modify.
> - **Types & Interfaces**: Classes, interfaces, enums, or type aliases introduced or changed, with full signatures.
> - **Behaviour**: Precise enough for a developer to implement without design decisions.
> - **Dependencies**: Which earlier steps this depends on.
> - **Notes**: Edge cases, idempotency, rollback strategy, or references to existing code.
>
> ## Test Plan
>
> For each acceptance criterion: test type (unit, integration, acceptance), file path, what is asserted.
>
> ## ADR Impact
>
> List new or updated ADR entries, or "None."
>
> ## Tools used
>
> ### SKILLS
> List skills used by the agent while creating the report, or "None."
>
> ### MCP tools
> List MCP tools used by the agent while creating the report, or "None."

### Review Response Template

When responding to Critic feedback on a plan:

> - **Changes Made**: List of updates to the plan.
> - **Unaddressed Feedback**: Justification for each omission.
