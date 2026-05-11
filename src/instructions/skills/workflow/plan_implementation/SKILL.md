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

## Third-party library integration — MUST

When the plan introduces a use of a third-party library (any namespace not under the project's own root namespace), the architect MUST cite the source-of-truth for the namespace and any API symbol used. Acceptable cites are:

- the library's `composer.json` autoload section with file path + line reference, OR
- a specific class file in the vendor tree with file path + class name, OR
- the library's official README or documentation URL with the symbol name visible at that URL.

Hypothetical, recalled, or AI-completed API surfaces are forbidden — verify before writing. The cite belongs in the Step's `**Notes**` section. Cites are required for:

- namespace + class name (e.g., `ApprovalTests\Approvals` — NOT `Approve\Approvals`),
- method signatures the plan calls,
- configuration options the plan sets.

A plan that introduces a third-party library without source-of-truth cites is a defect — the critic will raise it as a BLOCKER and force a re-spin.

## Third-party API reference marker — MUST

Every reference at Step >0 to a class, method, function, namespace, or file path under `vendor/` (or any namespace not under the project's own root namespace) MUST be either:

1. **Accompanied by an inline source citation** in the form `// per vendor/<pkg>/<file>:<line>` or `// per <official-doc-url>`, OR
2. **Preceded by a `[VERIFY: <gate-id>]` marker** referencing a Step 0 verification gate that produces the citation as its deliverable. Example: `[VERIFY: gate-B] $approver = new \Approvals\ApprovalRunner();` where Step 0 gate-B is specified to produce a scratch note `vendor-approvals-api.md` enumerating the available classes.

**Scope**: PHP core globals (`\Throwable`, `\Stringable`, `\DateTimeImmutable`, etc.) are exempt — they are part of the language, not third-party. The rule applies to any namespace whose top-level segment matches a `composer.json` `require` entry (excluding `php` and `ext-*`).

The Pre-FINISHED Hygiene Gate (below) executes the mechanical check that enforces this rule. The architect MUST either add an inline citation, add a `[VERIFY: <gate-id>]` marker, or remove the reference; an unverified third-party reference is a hygiene-gate failure.

## Plan Output

Save to `<issue-folder>/PLAN-ARCH-YYYY-MM-DD-NNN.md`. This file contains BOTH the architecture specification and the implementation plan in one document — see the architect's Deliverables section in `src/instructions/agents/architect.md` for the rationale and filename rules.

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
> **Test-isolation enumeration — MUST**: If any test in the Test Plan sources or executes the system-under-test (SUT) script as a whole (e.g. `bash bin/foo.sh` end-to-end, `. bin/foo.sh` to load definitions, or `source $SUT`) rather than calling specific functions in isolation, the plan MUST enumerate the side-effects that execution will fire during the test (per-app loops, network calls, filesystem mutations outside scratch dirs, subprocess spawns, side-effecting `set -e`/`trap` registrations) and EITHER (a) justify each side-effect as desired test behaviour with a one-line rationale, OR (b) design an isolation mechanism (marker-extraction sentinels + isolated `bash -c` source, env-gated branches like `[[ -n "${TELAMON_INIT_TEST:-}" ]] && return`, function extraction into a sourceable helper, or test-only stubs on PATH) and document the mechanism alongside the test cases. A test plan that sources the SUT without enumerating side-effects is incomplete; the critic MUST reject it as a BLOCKER. Rationale: a hermeticity defect discovered at critic time costs one revision cycle; the same defect surfaced at plan-write time costs one paragraph of enumeration.
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

## Verification-gate cross-referencing — MUST

When the plan introduces a verification gate between steps (a concrete process the developer must execute before proceeding — e.g. a "scratch note" mandate, a tooling-version check, a third-party API surface confirmation), every downstream step whose correctness depends on the gate's outcome MUST reference the gate from its top-line description, not just via inline warnings. Top-line means: the first sentence of the step's body, before any code blocks, file paths, or sub-headings. The reference must be phrased as a precondition, e.g.:

> **Precondition**: Bus API verification gate (between Step 0 and Step 1) has been executed and the scratch note exists.

Inline warnings later in the step are acceptable as reinforcement but not as the sole reference. Rationale: a developer reading the plan non-linearly (jumping to a specific step) must encounter the gate dependency at the same visual prominence as the step's title; advisory-feeling warnings deeper in the step body are bypassable. This rule applies to verification gates the architect introduces; the architect retains discretion over whether to introduce a gate at all.

## Pre-FINISHED Hygiene Gate

### Hygiene Gate output enumeration — MUST

The architect's FINISHED message for a plan MUST enumerate per-item evidence for each Hygiene Gate check, not summary counts. Specifically:

- **Item 4 (algorithm↔test traceability)**: enumerate per traced/behaviour-change/under-specified row.
- **Item 5 (verbatim-bar)**: instead of "N lines, M blocks", produce a table:

  ```
  | Line range | Block type      | Length | Justification (verbatim because …) |
  |------------|-----------------|--------|------------------------------------|
  | 102–161    | directory-tree  | 60     | navigability for implementer       |
  | 686–748    | code-sketch     | 63     | Step 13 wiring, three-way trace    |
  ```

- **Item 6 (third-party API references)**: instead of "N refs, M markers", produce a table:

  ```
  | Line | Reference            | Status                                     |
  |------|----------------------|--------------------------------------------|
  | 614  | \GetE\Bus\MessageBus | [VERIFY: gate-bus-api]                     |
  | 632  | \Approvals\Approver  | inline cite: vendor/approvals/.../A.php:42 |
  | 845  | \GetE\PhpOverlay     | [VERIFY: gate-overlay-purpose]             |
  ```

  Empty table = explicit "no third-party references" claim.

- **Item 7 (ADR Impact)**: enumerate the ADR identifiers found and the section's per-ADR rows.

The orchestrator MUST verify the FINISHED-message tables against the plan file (one `grep` per claimed line range) before accepting the FINISHED signal. A FINISHED message with summary counts instead of enumerated tables is invalid; the orchestrator MUST return the architect a `BLOCKED: hygiene_gate_output_unverifiable — enumerate per-item evidence per plan_implementation SKILL Hygiene Gate output enumeration rule` and re-delegate.

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
   - justify the verbatim inclusion with a **discriminating** one-line reason in the Step's `**Notes**` section. A discriminating justification cites a property that does NOT generalise to other verbatim blocks in the same plan. Generic phrases such as "exact assertion values required for algorithm traceability", "shown in full because the contract must be precise", or "needed for clarity" do NOT discriminate and are invalid — every block in a verbose plan can claim them. Examples of valid discriminating justifications:
     - "complex sort algorithm with non-obvious pivot selection — prose is ambiguous"
     - "byte-identical approval test fixture — any whitespace change breaks the test"
     - "regex with 4 lookarounds — escaping rules differ across PHP versions"
     - "exact exception class hierarchy required because PHPUnit's `expectException` checks `instanceof`, and the inheritance chain is contested in the backlog"

     A justification that could be copy-pasted onto a different block in the same plan is, by definition, not discriminating.

     Specific block types that do NOT pass the discriminating bar by default and MUST be summarised rather than included verbatim, unless the architect can cite an additional contract-bearing property the standard binding does not capture:

     - **Directory trees** — the contract is in PSR-4/namespace declarations + Step file paths; the tree is convenience. Default to a textual summary (e.g. "Component groups: X, Y, Z; ports under `Core/Port/<Component>/`; see PSR-4 autoload at line N") plus the PSR-4 block. A directory tree passes the bar only if the architect cites a property the standard binding does not capture, e.g. "non-standard layout deviates from PSR-4 in module M and the deviation must be reviewed line-by-line".
     - **Configuration scaffolds** (e.g., `composer.json`, `phpunit.xml`, framework config files) — the contract is the version-pinned dependency or the named extension; the surrounding YAML/JSON structure is boilerplate. Pass the bar only if a specific non-default key requires byte-identical reproduction (cite the key by name).
     - **Generated boilerplate** (e.g., autoload classmaps, full migration up/down stubs) — never pass the bar.

     When a tree or config block is the only convenient way to communicate a component grouping, prefer adding a small **Component Index** table (component name → directory path → kind) rather than the full tree.

   In addition, when the plan exceeds 900 lines, the architect MUST add a **Verbatim Inventory** section near the top of the plan (immediately after the Technology Choice section) listing every verbatim block ≥30 lines:

   | Step    | Block                 | Lines | Discriminating justification                       |
   |---------|-----------------------|-------|----------------------------------------------------|
   | Step 1  | `GrowthRate` enum     | 32    | exact case-name strings used as DB column values   |
   | Step 8  | `LevelCalculatorTest` | 84    | byte-identical approval-test fixture               |
   | …       | …                     | …     | …                                                  |

   The Verbatim Inventory exists to make verbose plans **auditable at a glance**: a reviewer can verify that each block earns its inclusion without reading the whole plan.

   Inline implementations are a smell — the developer's workspace is the place for full implementations, not the plan. The plan describes contracts and behaviour; the developer writes the implementation. Threshold rationale: 900 lines is the warning threshold calibrated on observed kata-scope plans (clean ≈800, bloated ≥1000). Report line count, Verbatim Inventory presence, and any blocks whose justifications fail the discriminating bar.

   **Revision-time verbatim-bar re-check (MUST)**: If the plan being signalled FINISHED is a **revision** (the plan file has prior `## Review Response` sections and the current line count exceeds the most recent prior FINISHED line count by >25%), the architect MUST re-run the verbatim-bar discriminating-bar check on every code block, directory tree, configuration excerpt, and namespace listing in the plan. For each block ≥30 lines (code) or ≥5 lines (tree/config/listing), the architect MUST either:

   1. **Re-justify** with an inline `# Verbatim because <reason citing block-type-specific bar>` comment if the block was added or grew during revision, OR
   2. **Remove** the block in favour of a citation or summary if the bar is no longer met (e.g. directory tree reducible to PSR-4 summary + new-file list).

   The revision-time re-check is in addition to the draft-time check. The architect MUST report the re-check outcome in the FINISHED message:

   ```
   Verbatim-bar revision re-check: <N> blocks evaluated, <M> re-justified, <K> removed. Plan size: <prior> → <current> lines (Δ +X%).
   ```

   If the plan size growth is ≤25%, the revision-time re-check is OPTIONAL but recommended. If >25%, MANDATORY. If the revised plan exceeds the 900-line soft ceiling AND the growth is >25%, the re-check is a precondition for FINISHED — the architect MUST execute it before signalling.
6. **Third-party API reference verification** — every Step >0 reference to a third-party namespace (per the `## Third-party API reference marker — MUST` rule above) must carry either an inline `// per …` citation OR a `[VERIFY: <gate-id>]` marker. Run the mechanical check:

   ```
   grep -nE '(\\\\[A-Z][a-zA-Z0-9_]+\\\\|new \\\\?[A-Z])' <plan-file> \
     | grep -v '^[^:]*:[^/]*//' \
     | grep -v '\[VERIFY:'
   ```

   Any line in the output is an unverified third-party reference. The check FAILS if any such line is found and is not exempt (PHP core globals — `\Throwable`, `\Stringable`, `\DateTimeImmutable`, etc. — are exempt). Report match count and exempt-line count separately.

7. **ADR Impact section presence** — the gate FAILS if the plan body satisfies any of the following triggers AND does not contain an `## ADR Impact` section:

   1. The Key Architect Decisions table has ≥3 rows.
   2. Any step body contains a reference to an ADR identifier matching the regex `\bADR-\d{3,}\b`.
   3. The plan introduces a new architectural pattern (port interface, new layer, new bounded context) — detectable via the Constraints or Glossary section.

   The §ADR Impact section MUST enumerate each affected ADR with a one-line impact statement using one of: `new` (this plan creates ADR-NNN), `superseded` (this plan supersedes ADR-NNN), `extended` (this plan extends ADR-NNN scope), `unchanged-but-cited` (this plan references ADR-NNN without modification).

   Mechanical check:

   ```
   if grep -qE '(\bADR-[0-9]{3,}\b)' <plan-file> && ! grep -q '^## ADR Impact' <plan-file>; then
     FAIL: ADR identifier referenced but no ADR Impact section
   fi
   ```

   Report: ADR identifiers found / ADR Impact section present / pass/fail.

Format in FINISHED message:

> Hygiene gate:
> 1. Residue grep: 0 matches
> 2. Single-version: yes
> 3. Trade-offs format: yes
> 4. Algorithm↔test traceability: N traced, M behaviour-change marked, 0 under-specified
> 5. Plan-size check: NNN lines (≤900: pass | >900: Verbatim Inventory present? yes/no; discriminating-justification audit: M blocks total, K passed, 0 must remain failed)
> 6. Third-party API references: K matches, J exempt, 0 unverified
> 7. ADR Impact: T identifiers found, section present? yes/no, pass/fail

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
