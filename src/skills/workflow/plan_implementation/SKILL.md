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
- When proposing to inline or remove an interface whose concrete is declared `readonly class`, the plan MUST include an explicit test-double strategy. Mockery cannot subclass readonly classes (engine fatal: `Cannot declare class ... because the parent class is readonly`). Acceptable strategies: (a) keep the interface and mock the interface; (b) drop the `readonly` modifier from the concrete; (c) provide a hand-written fake under `tests/Support/`. See `brain/gotchas.md` — "Mockery cannot mock `readonly class`".

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
> - **Failure modes considered** — REQUIRED for any Step whose Layer is one of: `Infrastructure`, `Wiring`, `Presentation`, OR any Step in `Application` that introduces a new handler/use-case, OR any Step in `Domain` that defines a port (interface). NOT required for pure Domain entity/value-object steps, pure DTO definition steps, or migration-only steps. List the top 3 ways this step's integration surface could break or be misused later — silent recursion, double-registration, missing handler, race, leaky lifecycle, partial failure under iteration, error-translation gap between layers, etc. For each, state whether the design eliminates the failure mode or whether a maintenance rule is documented inline. If a Step is ambiguous (could be Domain pure or could expose a port), default to including the block.
>
> ## Test Plan
>
> For each acceptance criterion: test type (unit, integration, acceptance), file path, what is asserted.
>
> **Note on AC↔Test mapping**: The Test Plan table maps acceptance criteria → test methods (one-way). A reverse `Test → AC` column is intentionally not required: acceptance test names are coarse by nature ("approval test in `tests/Acceptance/`") and forcing a per-test AC reference produces churn without catching defects. If a developer needs reverse traceability, the AC text in the table's AC column already provides it. This deferral was reviewed in iterations 2, 3, and 4 of the planning improvement loop with no defect ever linked to the gap.
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

## Pre-FINISHED Hygiene Gate

Before signalling `FINISHED!` for a plan deliverable, the architect MUST run this checklist against the plan file and report each result in the FINISHED message:

1. **Self-revision residue grep** — search the plan for: `Wait`, `Actually`, `let me re-`, `let me fix`, `let me redo`, `simplest approach`, `On reflection`, `Hmm`. Report match count. **Must be 0** outside fenced code blocks. If matches found, edit them out before signalling FINISHED.
2. **Single-version check** — confirm no Step or section appears twice with conflicting content (e.g., "Step 7 (revised)" alongside "Step 7"). Report yes/no.
3. **Trade-offs format** — alternatives appear only inside `Trade-offs considered` subsections, never as inline "but actually X is better" passages. Report yes/no.
4. **Algorithm ↔ test traceability** — for every Test Plan row that references an algorithm or value-object behaviour defined elsewhere in the plan (or in the original source code being refactored), trace at least one expected value back to the algorithm sketch or original script line. If the test expectation does not match what the algorithm/script would produce for that input, the test is wrong (the plan must preserve the behaviour being refactored). Either:
   - correct the test expectation to match the algorithm, OR
   - explicitly mark the test as a *behaviour change* with rationale (e.g. "the original script crashed on empty input; we explicitly change this to return early").

   If you cannot trace a test expectation to a deterministic source (algorithm sketch line, original code line, AC text), the test is under-specified and must not ship in the plan. Report `traced` / `behaviour-change marked` / `under-specified` count.
5. **Plan-size check** — count lines (`wc -l`). If the plan exceeds 900 lines for a single-component scope, identify all code sketches over 30 lines. For each:
   - either summarise as `### Behaviour` (bulleted list) + `### Contract` (signatures only) + `### Implementation file` (path reference), removing the full body, OR
   - justify the verbatim inclusion in the Step's `**Notes**` section with a one-line reason (e.g. "complex sort algorithm where prose is ambiguous", "exact test class shape required for byte-identical comparison").

   Inline implementations are a smell — the developer's workspace is the place for full implementations, not the plan. The plan describes contracts and behaviour; the developer writes the implementation. Threshold rationale: 900 lines is the warning threshold calibrated on observed kata-scope plans (clean ≈800, bloated ≥1000). Report line count and any verbatim-justified blocks.

Format in FINISHED message:

> Hygiene gate:
> 1. Residue grep: 0 matches
> 2. Single-version: yes
> 3. Trade-offs format: yes
> 4. Algorithm↔test traceability: N traced, M behaviour-change marked, 0 under-specified
> 5. Plan-size check: NNN lines (≤900: pass | >900: list verbatim-justified blocks)

A FINISHED signal that omits this block, or that reports any failure without an accompanying fix, is invalid. The orchestrator MUST treat it as `PARTIAL` and re-delegate with the failing items called out.

### Review Response Template

When responding to Critic feedback on a plan:

> - **Changes Made**: List of updates to the plan.
> - **Unaddressed Feedback**: Justification for each omission.
> - **Backlog Deltas**: List every backlog task whose contract has changed as a result of this revision (return type, method signature, included VOs/DTOs, acceptance-criteria text). For each delta, state:
>   - Backlog task number and short title.
>   - Old contract (one line, quoted from current backlog).
>   - New contract (one line, matching the revised plan).
>   - Classification: `contract-shape` (signature/return-type/structural) or `documentation-only` (wording, typos, references).
>   - If no backlog tasks are affected, write: "No backlog deltas — plan revision is internal to the plan document."

The orchestrator routes Backlog Deltas as follows:

- Any `contract-shape` delta → re-delegate to PO to update the backlog.
- All deltas `documentation-only` → orchestrator may self-fix per the existing critic-finding routing rule.

A FINISHED signal that omits the `Backlog Deltas` line is invalid. The orchestrator MUST treat it as `PARTIAL` and re-delegate with the missing item called out.
