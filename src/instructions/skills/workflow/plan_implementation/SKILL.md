---
name: telamon.plan_implementation
description: "Creates implementation plans from a brief. Use when designing a technical plan that addresses all layers (domain, application, infrastructure, presentation, wiring, migrations, tests)."
---

# Skill: Implementation Planning

Create detailed, step-by-step implementation plan from brief that developer can follow without making design decisions.

## When to Apply

- Orchestrator provides approved backlog and requests technical plan
- Creating or revising implementation plan for feature or change

## Design Principles

Follow these principles when designing plan:

- Analyze existing codebase patterns before proposing new ones. Prefer established conventions; document deviations in ADRs.
- Reference existing code as precedent. Legacy sections (defined in project-specific context files) MUST NOT be used as precedent.
- Specify Value Objects for domain concepts (names, IDs, scores, URLs, etc.).
- Port contracts MUST use typed DTOs — never raw arrays crossing boundaries.
- Port interfaces MUST NOT expose transport or infrastructure concepts.
- Application services returning data to presentation MUST return DTOs — never domain entities.
- Exceptions crossing layer boundaries MUST be defined at port level.
- Design all event handlers and projections for idempotency.
- Every schema change needs migration plan with rollback strategy.
- When proposing to inline or remove interface whose concrete declared `readonly class`, plan MUST include explicit test-double strategy. Mockery cannot subclass readonly classes (engine fatal: `Cannot declare class ... because parent class is readonly`). Acceptable strategies: (a) keep interface and mock interface; (b) drop `readonly` modifier from concrete; (c) provide hand-written fake under `tests/Support/`. See `latent/global/ or latent/project/` — "Mockery cannot mock `readonly class`".

## Third-party library integration — MUST

When plan introduces third-party library (any namespace not under project's own root namespace), architect MUST cite source-of-truth for namespace and any API symbol used. Acceptable cites:

- library's `composer.json` autoload section with file path + line reference, OR
- specific class file in vendor tree with file path + class name, OR
- library's official README or documentation URL with symbol name visible at that URL.

Hypothetical, recalled, or AI-completed API surfaces are forbidden — verify before writing. Cite belongs in Step's `**Notes**` section. Cites required for:

- namespace + class name (e.g., `ApprovalTests\Approvals` — NOT `Approve\Approvals`),
- method signatures plan calls,
- configuration options plan sets.

Plan introducing third-party library without source-of-truth cites is defect — critic raises as BLOCKER and forces re-spin.

## Third-party API reference marker — MUST

Every reference at Step >0 to class, method, function, namespace, or file path under `vendor/` (or any namespace not under project's own root namespace) MUST be either:

1. **Accompanied by inline source citation** in form `// per vendor/<pkg>/<file>:<line>` or `// per <official-doc-url>`, OR
2. **Preceded by `[VERIFY: <gate-id>]` marker** referencing Step 0 verification gate that produces citation as its deliverable. Example: `[VERIFY: gate-B] $approver = new \Approvals\ApprovalRunner();` where Step 0 gate-B specified to produce scratch note `vendor-approvals-api.md` enumerating available classes.

**Scope**: PHP core globals (`\Throwable`, `\Stringable`, `\DateTimeImmutable`, etc.) exempt — they are part of language, not third-party. Rule applies to any namespace whose top-level segment matches `composer.json` `require` entry (excluding `php` and `ext-*`).

Pre-FINISHED Hygiene Gate (below) executes mechanical check enforcing this rule. Architect MUST either add inline citation, add `[VERIFY: <gate-id>]` marker, or remove reference; unverified third-party reference is hygiene-gate failure.

## Plan Output

Save to `<issue-folder>/PLAN-ARCH-YYYY-MM-DD-NNN.md`. This file contains BOTH architecture specification and implementation plan in one document — see architect's Deliverables section in `src/instructions/agents/architect.md` for rationale and filename rules.

### Plan Template

> # Implementation Plan
>
> **Brief**: Reference to brief or task ID.
> **Status**: DRAFT | IN REVIEW | FINAL
>
> ## Technology Choice
>
> _(Place technology evaluation FIRST when plan involves choosing between competing tools, frameworks, or approaches. Readers MUST understand WHY before reading HOW.)_
>
> If no technology choice made, replace section with one-line note: "No technology evaluation required."
>
> When applicable, include:
> - **Discovery**: Search broadly for candidates — do not limit to well-known options. Use web search to find current alternatives, emerging projects, and recent benchmarks. Aim for minimum of 4-5 candidates before narrowing down. Include niche or newer projects that may be better fit for specific use case.
> - Comparison table covering relevant dimensions (installation impact, performance, maturity, feature coverage, migration risk, rollback complexity)
> - Decision with rationale — why chosen option wins for THIS project
> - When each rejected alternative would be right choice
>
> ### Official Documentation Review
>
> After selecting technology, **read its official documentation for exact deployment method used in this project** before writing YAML, config, or integration code. Do not rely on training data for tool-specific configuration.
>
> Specifically:
> - Find and read **installation guide matching project's deployment method** (e.g. ArgoCD, Helm, Terraform, Docker Compose — not just generic `kubectl apply`)
> - Identify **prerequisites** (CRDs, namespace setup, secrets, permissions) that MUST exist before main install
> - Identify **ordering constraints** (sync-waves, init containers, dependency chains) and gotchas (e.g. ArgoCD dry-run failures when CRDs installed by same sync)
> - Capture exact values for registry URLs, chart names, versions, API groups, and CRD kinds — do not guess from memory
> - Cite documentation URL for every tool-specific configuration value in plan
>
> ## Key Architect Decisions
>
> |#| Decision | Rationale |
> |-|----------|-----------|
>
> ## Constraints
>
> Project-wide coding rules applying to every Step in this plan. Source from `telamon.architecture_rules`, `telamon.php_rules`, `telamon.testing`, and any project-specific files under `.ai/<owner>/memory/bootstrap/`.
>
> Restate rules inline (do not link out) so reader of any single Step has all rules in immediate view. Bullet list, no prose. Cite source skill name in each bullet so reader can verify currency.
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
> Restate acceptance criteria. Flag gaps or ambiguities back to orchestrator.
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
> - **Behaviour**: Precise enough for developer to implement without design decisions.
> - **Dependencies**: Which earlier steps this depends on.
> - **Notes**: Edge cases, idempotency, rollback strategy, or references to existing code.
> - **Failure modes considered** — REQUIRED for any Step whose Layer is one of: `Infrastructure`, `Wiring`, `Presentation`, OR any Step in `Application` that introduces new handler/use-case, OR any Step in `Domain` that defines port (interface). NOT required for pure Domain entity/value-object steps, pure DTO definition steps, or migration-only steps. List top 3 ways this step's integration surface could break or be misused later — silent recursion, double-registration, missing handler, race, leaky lifecycle, partial failure under iteration, error-translation gap between layers, etc. For each, state whether design eliminates failure mode or whether maintenance rule documented inline. If Step ambiguous (could be Domain pure or could expose port), default to including block.
>
> ## Test Plan
>
> For each acceptance criterion: test type (unit, integration, acceptance), file path, what asserted.
>
> **Note on AC↔Test mapping**: Test Plan table maps acceptance criteria → test methods (one-way). Reverse `Test → AC` column intentionally not required: acceptance test names are coarse by nature ("approval test in `tests/Acceptance/`") and forcing per-test AC reference produces churn without catching defects. If developer needs reverse traceability, AC text in table's AC column already provides it. This deferral reviewed in iterations 2, 3, and 4 of planning improvement loop with no defect ever linked to gap.
>
> **Test-isolation enumeration — MUST**: If any test in Test Plan sources or executes system-under-test (SUT) script as whole (e.g. `bash bin/foo.sh` end-to-end, `. bin/foo.sh` to load definitions, or `source $SUT`) rather than calling specific functions in isolation, plan MUST enumerate side-effects that execution will fire during test (per-app loops, network calls, filesystem mutations outside scratch dirs, subprocess spawns, side-effecting `set -e`/`trap` registrations) and EITHER (a) justify each side-effect as desired test behaviour with one-line rationale, OR (b) design isolation mechanism (marker-extraction sentinels + isolated `bash -c` source, env-gated branches like `[[ -n "${TELAMON_INIT_TEST:-}" ]] && return`, function extraction into sourceable helper, or test-only stubs on PATH) and document mechanism alongside test cases. Test plan that sources SUT without enumerating side-effects is incomplete; critic MUST reject as BLOCKER. Rationale: hermeticity defect discovered at critic time costs one revision cycle; same defect surfaced at plan-write time costs one paragraph of enumeration. **Sub-rule — transitive `set -u` audit**: When chosen isolation mechanism is "marker-extraction sentinels + isolated `bash -c` source" or "function extraction into sourceable helper" AND SUT script runs under `set -u`, plan MUST list every shell variable sourced block reads and verify each has either default assignment (`${VAR:=...}` / `${VAR:-...}`) in sourced block, in test harness, or in explicitly-listed auxiliary file. If auxiliary file needs `:=` defaults added to make block source-able under `set -u`, plan MUST identify file and additions as in-scope (not "discovered during implementation"). Rationale: hermetic test sourcing transitively touches every file block depends on; unaudited transitives cause out-of-scope additions during dev cycle that reviewer cannot detect until plan-time gap is closed.
>
> **Test-stub argv-capture format — MUST**: If Test Plan includes test stub that intercepts subprocess invocation and captures argv for assertion (e.g. PATH-prepended fake `opencode` that logs how called), plan MUST specify token-per-line capture format (e.g. `printf '%s\n' "$@"` between explicit delimiters such as `argv-begin`/`argv-end`) rather than token-per-space format (e.g. loop with `printf ' %q' "$arg"` or naive `"$*"`). Rationale: token-per-line capture surfaces quoting bugs as argv-count differences in captured log; token-per-space capture collapses distinction between "1 quoted argument" and "N word-split arguments" into same logged string, hiding word-splitting defects from assertions. Plan designing argv-capturing stubs without specifying token-per-line capture is incomplete; critic MUST flag as WARNING (BLOCKER if production code under test passes user-controlled or whitespace-bearing strings to subprocess).
>
> ## ADR Impact
>
> List new or updated ADR entries, or "None."
>
> ## Tools used
>
> ### SKILLS
> List skills used by agent while creating report, or "None."
>
> ### MCP tools
> List MCP tools used by agent while creating report, or "None."

## Verification-gate cross-referencing — MUST

When plan introduces verification gate between steps (concrete process developer MUST execute before proceeding — e.g. "scratch note" mandate, tooling-version check, third-party API surface confirmation), every downstream step whose correctness depends on gate's outcome MUST reference gate from its top-line description, not just via inline warnings. Top-line means: first sentence of step body, before any code blocks, file paths, or sub-headings. Reference MUST be phrased as precondition, e.g.:

> **Precondition**: Bus API verification gate (between Step 0 and Step 1) executed and scratch note exists.

Inline warnings later in step acceptable as reinforcement but not as sole reference. Rationale: developer reading plan non-linearly (jumping to specific step) MUST encounter gate dependency at same visual prominence as step's title; advisory-feeling warnings deeper in step body are bypassable. This rule applies to verification gates architect introduces; architect retains discretion over whether to introduce gate at all.

## Pre-FINISHED Hygiene Gate

### Hygiene Gate output enumeration — MUST

Architect's FINISHED message for plan MUST enumerate per-item evidence for each Hygiene Gate check, not summary counts. Specifically:

- **Item 4 (algorithm↔test traceability)**: enumerate per traced/behaviour-change/under-specified row.
- **Item 5 (verbatim-bar)**: instead of "N lines, M blocks", produce table:

  ```
| Line range | Block type     | Length | Justification (verbatim because …) |
|------------|----------------|--------|------------------------------------|
| 102–161    | directory-tree | 60     | navigability for implementer       |
| 686–748    | code-sketch    | 63     | Step 13 wiring, three-way trace    |
  ```

- **Item 6 (third-party API references)**: instead of "N refs, M markers", produce table:

  ```
| Line | Reference            | Status                                     |
|------|----------------------|--------------------------------------------|
| 614  | \GetE\Bus\MessageBus | [VERIFY: gate-bus-api]                     |
| 632  | \Approvals\Approver  | inline cite: vendor/approvals/.../A.php:42 |
| 845  | \GetE\PhpOverlay     | [VERIFY: gate-overlay-purpose]             |
  ```

  Empty table = explicit "no third-party references" claim.

- **Item 7 (ADR Impact)**: enumerate ADR identifiers found and section's per-ADR rows.

Orchestrator MUST verify FINISHED-message tables against plan file (one `grep` per claimed line range) before accepting FINISHED signal. FINISHED message with summary counts instead of enumerated tables is invalid; orchestrator MUST return architect `BLOCKED: hygiene_gate_output_unverifiable — enumerate per-item evidence per plan_implementation SKILL Hygiene Gate output enumeration rule` and re-delegate.

Before signalling `FINISHED!` for plan deliverable, architect MUST run this checklist against plan file and report each result in FINISHED message:

1. **Self-revision residue grep** — search plan for: `Wait`, `Actually`, `let me re-`, `let me fix`, `let me redo`, `simplest approach`, `On reflection`, `Hmm`. Report match count. **Must be 0** outside fenced code blocks. If matches found, edit them out before signalling FINISHED.
2. **Single-version check** — confirm no Step or section appears twice with conflicting content (e.g. "Step 7 (revised)" alongside "Step 7"). Report yes/no.
3. **Trade-offs format** — alternatives appear only inside `Trade-offs considered` subsections, never as inline "but actually X is better" passages. Report yes/no.
4. **Algorithm ↔ test traceability** — for every Test Plan row referencing algorithm or value-object behaviour defined elsewhere in plan (or in original source code being refactored), trace at least one expected value back to algorithm sketch or original script line. If test expectation does not match what algorithm/script would produce for that input, test is wrong (plan MUST preserve behaviour being refactored). Either:
   - correct test expectation to match algorithm, OR
   - explicitly mark test as *behaviour change* with rationale (e.g. "original script crashed on empty input; we explicitly change this to return early").

   If cannot trace test expectation to deterministic source (algorithm sketch line, original code line, AC text), test is under-specified and MUST NOT ship in plan. Report `traced` / `behaviour-change marked` / `under-specified` count.
5. **Plan-size check** — count lines (`wc -l`). If plan exceeds 900 lines for single-component scope, identify all code sketches over 30 lines. For each:
   - either summarise as `### Behaviour` (bulleted list) + `### Contract` (signatures only) + `### Implementation file` (path reference), removing full body, OR
   - justify verbatim inclusion with **discriminating** one-line reason in Step's `**Notes**` section. Discriminating justification cites property that does NOT generalise to other verbatim blocks in same plan. Generic phrases such as "exact assertion values required for algorithm traceability", "shown in full because contract MUST be precise", or "needed for clarity" do NOT discriminate and are invalid — every block in verbose plan can claim them. Examples of valid discriminating justifications:
     - "complex sort algorithm with non-obvious pivot selection — prose ambiguous"
     - "byte-identical approval test fixture — any whitespace change breaks test"
     - "regex with 4 lookarounds — escaping rules differ across PHP versions"
     - "exact exception class hierarchy required because PHPUnit's `expectException` checks `instanceof`, and inheritance chain contested in backlog"

     Justification that could be copy-pasted onto different block in same plan is, by definition, not discriminating.

     Specific block types that do NOT pass discriminating bar by default and MUST be summarised rather than included verbatim, unless architect can cite additional contract-bearing property standard binding does not capture:

     - **Directory trees** — contract is in PSR-4/namespace declarations + Step file paths; tree is convenience. Default to textual summary (e.g. "Component groups: X, Y, Z; ports under `Core/Port/<Component>/`; see PSR-4 autoload at line N") plus PSR-4 block. Directory tree passes bar only if architect cites property standard binding does not capture, e.g. "non-standard layout deviates from PSR-4 in module M and deviation MUST be reviewed line-by-line".
     - **Configuration scaffolds** (e.g. `composer.json`, `phpunit.xml`, framework config files) — contract is version-pinned dependency or named extension; surrounding YAML/JSON structure is boilerplate. Pass bar only if specific non-default key requires byte-identical reproduction (cite key by name).
     - **Generated boilerplate** (e.g. autoload classmaps, full migration up/down stubs) — never pass bar.

     When tree or config block is only convenient way to communicate component grouping, prefer adding small **Component Index** table (component name → directory path → kind) rather than full tree.

   In addition, when plan exceeds 900 lines, architect MUST add **Verbatim Inventory** section near top of plan (immediately after Technology Choice section) listing every verbatim block ≥30 lines:

| Step   | Block                 | Lines | Discriminating justification                     |
|--------|-----------------------|-------|--------------------------------------------------|
| Step 1 | `GrowthRate` enum     | 32    | exact case-name strings used as DB column values |
| Step 8 | `LevelCalculatorTest` | 84    | byte-identical approval-test fixture             |
| …      | …                     | …     | …                                                |

   Verbatim Inventory exists to make verbose plans **auditable at glance**: reviewer can verify each block earns its inclusion without reading whole plan.

   Inline implementations are smell — developer's workspace is place for full implementations, not plan. Plan describes contracts and behaviour; developer writes implementation. Threshold rationale: 900 lines is warning threshold calibrated on observed kata-scope plans (clean ≈800, bloated ≥1000). Report line count, Verbatim Inventory presence, and any blocks whose justifications fail discriminating bar.

   **Revision-time verbatim-bar re-check (MUST)**: If plan being signalled FINISHED is **revision** (plan file has prior `## Review Response` sections and current line count exceeds most recent prior FINISHED line count by >25%), architect MUST re-run verbatim-bar discriminating-bar check on every code block, directory tree, configuration excerpt, and namespace listing in plan. For each block ≥30 lines (code) or ≥5 lines (tree/config/listing), architect MUST either:

   1. **Re-justify** with inline `# Verbatim because <reason citing block-type-specific bar>` comment if block added or grew during revision, OR
   2. **Remove** block in favour of citation or summary if bar no longer met (e.g. directory tree reducible to PSR-4 summary + new-file list).

   Revision-time re-check is in addition to draft-time check. Architect MUST report re-check outcome in FINISHED message:

   ```
   Verbatim-bar revision re-check: <N> blocks evaluated, <M> re-justified, <K> removed. Plan size: <prior> → <current> lines (Δ +X%).
   ```

   If plan size growth ≤25%, revision-time re-check OPTIONAL but recommended. If >25%, MANDATORY. If revised plan exceeds 900-line soft ceiling AND growth >25%, re-check is precondition for FINISHED — architect MUST execute it before signalling.
6. **Third-party API reference verification** — every Step >0 reference to third-party namespace (per `## Third-party API reference marker — MUST` rule above) MUST carry either inline `// per …` citation OR `[VERIFY: <gate-id>]` marker. Run mechanical check:

   ```
   grep -nE '(\\\\[A-Z][a-zA-Z0-9_]+\\\\|new \\\\?[A-Z])' <plan-file> \
     | grep -v '^[^:]*:[^/]*//' \
     | grep -v '\[VERIFY:'
   ```

   Any line in output is unverified third-party reference. Check FAILS if any such line found and not exempt (PHP core globals — `\Throwable`, `\Stringable`, `\DateTimeImmutable`, etc. — exempt). Report match count and exempt-line count separately.

7. **ADR Impact section presence** — gate FAILS if plan body satisfies any of following triggers AND does not contain `## ADR Impact` section:

   1. Key Architect Decisions table has ≥3 rows.
   2. Any step body contains reference to ADR identifier matching regex `\bADR-\d{3,}\b`.
   3. Plan introduces new architectural pattern (port interface, new layer, new bounded context) — detectable via Constraints or Glossary section.

   §ADR Impact section MUST enumerate each affected ADR with one-line impact statement using one of: `new` (this plan creates ADR-NNN), `superseded` (this plan supersedes ADR-NNN), `extended` (this plan extends ADR-NNN scope), `unchanged-but-cited` (this plan references ADR-NNN without modification).

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
> 5. Plan-size check: NNN lines (≤900: pass | >900: Verbatim Inventory present? yes/no; discriminating-justification audit: M blocks total, K passed, 0 MUST remain failed)
> 6. Third-party API references: K matches, J exempt, 0 unverified
> 7. ADR Impact: T identifiers found, section present? yes/no, pass/fail

FINISHED signal that omits this block, or that reports any failure without accompanying fix, is invalid. Orchestrator MUST treat as `PARTIAL` and re-delegate with failing items called out.

### Review Response Template

When responding to Critic feedback on plan:

> - **Changes Made**: List of updates to plan.
> - **Unaddressed Feedback**: Justification for each omission.
> - **Backlog Deltas**: List every backlog task whose contract changed as result of this revision (return type, method signature, included VOs/DTOs, acceptance-criteria text). For each delta, state:
>   - Backlog task number and short title.
>   - Old contract (one line, quoted from current backlog).
>   - New contract (one line, matching revised plan).
>   - Classification: `contract-shape` (signature/return-type/structural) or `documentation-only` (wording, typos, references).
>   - If no backlog tasks affected, write: "No backlog deltas — plan revision is internal to plan document."

Orchestrator routes Backlog Deltas as follows:

- Any `contract-shape` delta → re-delegate to PO to update backlog.
- All deltas `documentation-only` → orchestrator may self-fix per existing critic-finding routing rule.

FINISHED signal that omits `Backlog Deltas` line is invalid. Orchestrator MUST treat as `PARTIAL` and re-delegate with missing item called out.
