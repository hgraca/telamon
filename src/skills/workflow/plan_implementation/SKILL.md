---
name: telamon.plan_implementation
description: "Creates implementation plans from a brief. Use when designing a technical plan that addresses all layers (domain, application, infrastructure, presentation, wiring, migrations, tests)."
---

# Skill: Implementation Planning

Create a detailed, step-by-step implementation plan from a brief that a developer can follow without making design decisions.

## When to Apply

- When the orchestrator provides an approved backlog and requests a technical plan
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

Save to `<issue-folder>/PLAN-ARCH-YYYY-MM-DD-NNN.md`. This file contains BOTH the architecture specification and the implementation plan in one document — see the architect's Deliverables section in `src/agents/architect.md` for the rationale and filename rules.

### Plan Template

> # Implementation Plan
>
> **Brief**: Reference to the brief or task ID.
> **Status**: DRAFT | IN REVIEW | FINAL
>
> ## Technology Choice
>
> _(Place technology evaluation FIRST when the plan involves choosing between competing tools, frameworks, or approaches. Readers must understand WHY before reading HOW.)_
>
> If no technology choice was made, replace this section with a one-line note: "No technology evaluation required."
>
> When applicable, include:
> - **Discovery**: Search broadly for candidates — do not limit to well-known options. Use web search to find current alternatives, emerging projects, and recent benchmarks. Aim for a minimum of 4-5 candidates before narrowing down. Include niche or newer projects that may be a better fit for the specific use case.
> - Comparison table covering relevant dimensions (installation impact, performance, maturity, feature coverage, migration risk, rollback complexity)
> - Decision with rationale — why the chosen option wins for THIS project
> - When each rejected alternative would be the right choice
>
> ### Official Documentation Review
>
> After selecting a technology, **read its official documentation for the exact deployment method used in this project** before writing YAML, config, or integration code. Do not rely on training data for tool-specific configuration.
>
> Specifically:
> - Find and read the **installation guide matching the project's deployment method** (e.g., ArgoCD, Helm, Terraform, Docker Compose — not just generic `kubectl apply`)
> - Identify **prerequisites** (CRDs, namespace setup, secrets, permissions) that must exist before the main install
> - Identify **ordering constraints** (sync-waves, init containers, dependency chains) and gotchas (e.g., ArgoCD dry-run failures when CRDs are installed by the same sync)
> - Capture exact values for registry URLs, chart names, versions, API groups, and CRD kinds — do not guess from memory
> - Cite the documentation URL for every tool-specific configuration value in the plan
>
> ## Key Architect Decisions
> 
> |#| Decision | Rationale |
> |-|----------|-----------|
>
> ## Constraints
>
> Project-wide coding rules that apply to every Step in this plan. Source from `telamon.architecture_rules`, `telamon.php_rules`, `telamon.testing`, and any project-specific files under `.ai/<owner>/memory/project-rules/`.
>
> Restate the rules inline (do not link out) so a reader of any single Step has all rules in immediate view. Bullet list, no prose. Cite the source skill name in each bullet so a reader can verify currency.
>
> Required topics:
> - Type strictness (declarations, return types, generics)
> - Immutability defaults
> - Naming conventions (classes, methods, files)
> - Security MUST/MUST NOT
> - Testing rules (test-level placement, fixture style)
> - Any framework-specific lifecycle rules in scope
>
> ## Acceptance Criteria
>
> Restate the acceptance criteria. Flag gaps or ambiguities back to the orchestrator.
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
> - **Failure modes considered** (Wiring/Infrastructure steps only): list the top 3 ways this wiring or adapter could break or be misused later — silent recursion, double-registration, missing handler, race, leaky lifecycle, etc. For each, state whether the design eliminates the failure mode or whether a maintenance rule is documented inline.
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
