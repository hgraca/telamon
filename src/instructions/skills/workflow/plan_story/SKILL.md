---
name: telamon.plan_story
description: "Plans a user story by producing a backlog, architecture specification, and optional UI/UX specification. Use when a human stakeholder provides a story, feature request, or business initiative that needs planning before implementation."
---

# Skill: Plan Story

Produce a plan for a user story composed of:
- Issue backlog in `backlog.md` — clear, small, prioritized issues with requirements and acceptance criteria
- Architecture specification (if necessary)
- UI/UX specification (if necessary)

## When to Apply

- When a human stakeholder provides a story, feature request, or business initiative
- When the `/plan` or `/story` command is invoked
- When an epic is broken into stories that each need planning

## Artifacts

Place all artifacts in a single `<issue-folder>` under `.ai/telamon/memory/work/active/`. Planning artifacts must not be committed to git.

### Scratch files

When you need to create a temporary file, use the `telamon.thinking` skill. Promote any useful findings from `thinking/` to the appropriate brain file or issue artifact before closing the session.

### Folder naming

`.ai/telamon/memory/work/active/YYYYMMDD-HHMMSS-NN-<title_slug>/`

`YYYYMMDD-HHMMSS` is the current UTC timestamp. `NN` is a zero-padded sequential number. Check existing folders in `.ai/telamon/memory/work/active/` and use the next available number. The timestamp prefix provides chronological ordering; the sequential number disambiguates folders created in the same second.

### One folder per initiative — MUST

Each epic or story MUST have exactly one folder. NEVER create a second folder for the same initiative. Sub-story artifacts within an epic go in sub-folders of the epic folder (e.g., `.ai/telamon/memory/work/active/20260420-143000-01-helm-migration/20260420-144500-03-openbao/`).

## Procedure

### Step 0: Pre-flight

1. Read brain/ notes per the `telamon.recall_memories` skill. Identify entries relevant to the current scope. Include applicable lessons in all delegations.
2. **Check for existing issue folder**: List `.ai/telamon/memory/work/active/` and look for a folder that matches the current initiative (by slug or topic). If one exists, reuse it — do NOT create a new folder. If multiple folders exist for the same initiative, consolidate into the correctly-named one and delete the duplicate.

### Step 1: Create backlog

Delegate to @po to create `<issue-folder>/backlog.md` with prioritized tasks, requirements, and acceptance criteria.

- PO must apply the backlog rules below when writing tasks.
- PO saves to `<issue-folder>/backlog.md`, signals FINISHED with the backlog.
- If the PO signals NEEDS_INPUT, relay the question to the human stakeholder and re-delegate with the answer.

### Step 2: Architecture and implementation plan

Delegate to @architect to review the backlog and produce a combined architecture-and-implementation plan.

- Architect must produce a concrete directory tree mapping every source file to an assigned path.
- Architect produces a **single** `<issue-folder>/PLAN-ARCH-YYYY-MM-DD-NNN.md` file containing BOTH the architecture spec and the implementation plan. Do NOT instruct the architect to split these into separate `ARCH-*.md` and `PLAN-*.md` files. The exact internal structure is defined in the `telamon.plan_implementation` skill; the architect's deliverable contract is in `src/instructions/agents/architect.md`.
- Architect signals FINISHED with the file path. The orchestrator routes it to @critic in Step 4.

#### Spike-during-planning rule

When the plan depends on a third-party API capability (plugin hooks, SDK features, undocumented runtime behavior, etc.) AND the project's existing brain/ notes do not already confirm that capability, instruct the architect to run a verification spike DURING planning, not as Task 0 of implementation. Adding the spike to the implementation backlog leaves the architecture spec resting on unverified assumptions and forces fallback designs to be carried through review.

A 5-minute API check during planning eliminates the need for fallback design sections in the spec. Skip this rule only when the architect explicitly cites a brain/ note (gotcha, ADR, or pattern) that already confirms the relevant API capability.

### Step 3: UI/UX review (if applicable)

If UI work is needed, delegate to @ui-designer and/or @ux-designer to review the backlog.

- UI Designer saves to `<issue-folder>/UI-YYYY-MM-DD-NNN.md`, signals FINISHED with report.
- UX Designer saves to `<issue-folder>/UX-YYYY-MM-DD-NNN.md`, signals FINISHED with report.

Skip this step if the story has no UI component.

### Step 4: Critic review loop

Delegate to @critic for feedback on all documents produced so far.

- Critic saves to `<issue-folder>/PLAN-REVIEW-YYYY-MM-DD-NNN.md` per the `telamon.review_plan` skill (do NOT use a `CRITIC-*.md` prefix).
- Address issues deemed necessary.
- Justify issues that will not be addressed.
- After addressing findings, update `PLAN-ARCH-*.md` in place so its directory tree, code snippets, and step list match the revised backlog. Change the file's `Status` from `DRAFT`/`IN REVIEW` to `FINAL` when the critic loop concludes with no remaining BLOCKERs.
- Terminate the loop if progress stalls or goals shift — ask human stakeholder for direction.
- Iterate from step 3 until no remaining issues to address.

#### Review/revision state-transition table — MUST

The planning state machine has exactly four legal transitions out of any critic verdict. The orchestrator MUST consult this table after every critic round and select the unique matching row. Any other transition is invalid.

| Critic verdict         | Has unresolved findings? | Next state | Next delegation                                                      |
|------------------------|--------------------------|------------|----------------------------------------------------------------------|
| APPROVED               | No                       | FINAL      | (none — orchestrator promotes per `telamon.md` FINAL-promotion gate) |
| APPROVED               | Yes (any severity)       | IN REVIEW  | architect (revision cycle for new findings)                          |
| CHANGES REQUESTED      | (always)                 | IN REVIEW  | architect (revision cycle for all findings)                          |
| CONDITIONALLY APPROVED | (always)                 | IN REVIEW  | architect (revision cycle for unmet conditions)                      |

**Forbidden transition (MUST NOT)**: Consecutive critic rounds without an intervening architect revision. If the previous critic round returned CHANGES REQUESTED, CONDITIONALLY APPROVED, or APPROVED-with-findings, the orchestrator MUST delegate revision to the architect before any further critic delegation. A critic invocation that violates this rule is invalid; its output MUST NOT be merged into the audit log without a corresponding architect-revision Delegation entry preceding it. If the orchestrator believes a "second opinion" review is warranted, the architect MUST first produce a Review Response section explaining why no changes are needed (this counts as the intervening revision step) before the next critic round.

**Confirming-review feedback handling — MUST**: A confirming critic round (the round following an architect revision that addressed prior BLOCKERs) may return verdict `APPROVED` while still surfacing one or more new findings (any severity, including MINOR). When this happens, do NOT transition the plan to `Status: FINAL`. Re-delegate to the architect for one resolution pass. The architect's deliverable is an updated `PLAN-ARCH-*.md` plus an addition to the Review Response section that, for each new finding, records either:

- the fix applied (citing the line range or section), OR
- an explicit dispensation (citing the finding's identifier and severity, with a one-line rationale).

After the architect's pass, the orchestrator verifies the Review Response covers every new finding from the confirming review, then transitions the plan to `Status: FINAL` without an additional critic round (the verdict is already `APPROVED`; the cycle exists only to close the per-finding ledger). If the confirming review returns `APPROVED` with zero new findings, transition directly to `Status: FINAL`. Rationale: a confirming review whose new feedback receives no architect cycle is decorative; the per-finding ledger is the FINAL gate, and the gate is meaningless if findings are silently dropped.

### Step 5: Planning summary and approval

1. Create `<issue-folder>/summary.md` by following the `telamon.summarize_plan` skill.
2. Format all markdown files in the issue folder using the `format-md` tool with the issue folder path.
3. Output the summary to the human stakeholder and ask for final approval.
4. Write `<issue-folder>/planning-complete.md` as the final closing-checklist artifact, listing each required artifact with its **existence-verified AND canonical-path-verified** status. This file MUST be the orchestrator's last write before reporting completion to the human stakeholder.

   Each `[x]` line MUST cite the **canonical SKILL-prescribed path** under `<issue-folder>` (resolved to the absolute path of the issue folder created in Step 1) AND the **verifying tool call** that confirms the file is at that path. An existence-only check that does not bind the file to its canonical path is invalid — the line MUST remain `[ ]` until the file is at the correct path.

   Required artifacts and their canonical paths:
   - `<issue-folder>/backlog.md` — refined, every task has acceptance criteria and priority.
   - `<issue-folder>/PLAN-ARCH-YYYY-MM-DD-NNN.md` — `Status: FINAL`, set by orchestrator only after critic round APPROVED.
   - `<issue-folder>/PLAN-REVIEW-YYYY-MM-DD-NNN.md` — at least one with verdict APPROVED dated after the latest architect revision.
   - `<issue-folder>/summary.md` — written by the `telamon.summarize_plan` skill.
   - `<issue-folder>/retrospective/planning.md` — written by the `telamon.retrospective` skill.

   For each artifact, the orchestrator MUST `read` it at its canonical path (or `ls` the directory and confirm a non-empty file exists at that path) BEFORE listing it as `[x]`. Listing without verification, or verification at a non-canonical path, is forbidden — the proof is the tool call against the canonical path, not the assertion.

   Verification format — each `[x]` line MUST take this shape:

   - [x] `<absolute-or-workspace-relative-canonical-path>` (verified by `<tool>` at `<ISO-8601 timestamp>` — `<evidence>`)

   Example body:

   ```markdown
   # Planning complete — 20260508-143000-01-pokeapi-bus-refactor

   Issue folder: `.ai/telamon/memory/work/active/20260508-143000-01-pokeapi-bus-refactor/`

   Verified at: 2026-05-08T15:30:00Z

   - [x] `.ai/telamon/memory/work/active/20260508-143000-01-pokeapi-bus-refactor/backlog.md`
         (verified by `read` — 257 lines, 10 tasks across 5 phases)
   - [x] `.ai/telamon/memory/work/active/20260508-143000-01-pokeapi-bus-refactor/PLAN-ARCH-2026-05-08-001.md`
         (verified by `read` — Status: FINAL on line 4)
   - [x] `.ai/telamon/memory/work/active/20260508-143000-01-pokeapi-bus-refactor/PLAN-REVIEW-2026-05-08-002.md`
         (verified by `read` — verdict: APPROVED on line 3)
   - [x] `.ai/telamon/memory/work/active/20260508-143000-01-pokeapi-bus-refactor/summary.md`
         (verified by `read` — 87 lines)
   - [x] `.ai/telamon/memory/work/active/20260508-143000-01-pokeapi-bus-refactor/retrospective/planning.md`
         (verified by `read` — 43 lines)
   ```

   If any artifact is NOT at its canonical path, the line is `[ ] <canonical-path> — NOT AT CANONICAL PATH (found at <actual-path>)` or `[ ] <canonical-path> — MISSING`, and the orchestrator treats the planning stage as PARTIAL per the closing gate below. Move the file to the canonical path and re-verify before marking `[x]`. This is the planning equivalent of the @tester gate: the planning stage is complete only when this file exists and lists every required artifact as `[x]` at its canonical path with a verifying tool call.

#### Complete-side enumeration — MUST

The closing checklist and the closing summary are sound-side AND complete-side. Sound-side (already established by the canonical-path verification above): every listed artefact must exist on disk with a verifying tool call. Complete-side (this rule): every produced artefact in the issue folder must appear in the listing.

**Step 5 procedure addendum**:

1. Run `glob` for `PLAN-REVIEW-*.md` in `<issue-folder>`. For each match, the closing checklist (`planning-complete.md`) and the summary (`summary.md` Artifacts Produced table) MUST contain one entry naming the file, its verdict (APPROVED / CHANGES REQUESTED / CONDITIONALLY APPROVED), and a one-line role (e.g. `superseded`, `latest-approved`, `confirming`, `orphan-investigation-required`).
2. Run `glob` for `PLAN-ARCH-*.md` in `<issue-folder>`. Same enumeration rule (each file listed with status and role).
3. Run `glob` for any other `*.md` artefact in `<issue-folder>` (backlog, summary, retrospective, scratch). Each must appear in the closing checklist either as a required artefact or as `not required by skill — present for context`.
4. If any glob match is unlisted in `planning-complete.md` after step 1–3, the gate FAILS. The orchestrator MUST add the missing entry (with role + verifying tool call) before proceeding.

**Audit-log enumeration (MUST)**: `interactions.md` MUST contain one Delegation entry per producing subagent invocation. Specifically:

- For each `PLAN-REVIEW-*.md` file in the issue folder, `interactions.md` MUST have ≥1 critic Delegation entry whose deliverable matches that file's path.
- For each `PLAN-ARCH-*.md` file (and each architect-revision recorded in a Review Response section), `interactions.md` MUST have ≥1 architect Delegation entry.
- For each backlog file, `interactions.md` MUST have ≥1 PO Delegation entry.

If a produced deliverable has no corresponding Delegation entry, the orchestrator MUST add the missing Delegation entry before the closing-checklist gate passes. The added entry MUST cite the deliverable path as evidence and may use `RECONSTRUCTED FROM ARTEFACT` as the recovery-method tag.

#### Per-Agent Totals reconciliation across all closing artefacts — MUST

Every agent-count claim in ANY closing artefact (`summary.md`, `retrospective/planning.md`, `retrospective/implementation.md`, `planning-complete.md`, and any other `<issue-folder>/**/*.md` file produced at the closing checklist stage) MUST reconcile against the count of Delegation entries in `interactions.md` per agent role.

**Procedure**:

1. Compute `delegation_count[agent]` from `interactions.md` (one count per role: PO, architect, critic, tester, developer, reviewer, designer).
2. Compute `deliverable_count[agent]` from `glob` per agent's expected deliverable filename pattern:
   - critic: `glob` for `PLAN-REVIEW-*.md` in `<issue-folder>`.
   - architect: `glob` for `PLAN-ARCH-*.md` in `<issue-folder>` PLUS the count of architect-revision entries in any `Review Response` section.
   - PO: `glob` for `backlog.md` and any `backlog-delta-*.md` in `<issue-folder>`.
   - Other agents: `glob` for the agent's expected deliverable filename pattern.
3. Confirm `delegation_count[agent] >= deliverable_count[agent]` for each subagent. If any agent's `delegation_count < deliverable_count`, the orchestrator MUST add the missing Delegation entries — citing the produced deliverable as evidence — before the gate passes.
4. For each closing artefact in the issue folder, `grep` the artefact for any agent-count claim (patterns: `\d+ (PO|architect|critic|tester|developer|reviewer|designer)`, or `Total subagent invocations: \d+`, or any cell in a Per-Agent Totals table).
5. For every match, verify the cited number equals `delegation_count[agent]` (or the sum if the claim is "Total"). Mismatches FAIL the gate.
6. The orchestrator MUST update mismatched artefacts with reconciled counts, annotating reconstructed entries with `RECONSTRUCTED FROM ARTEFACT` and citing the source-of-truth (delegation count from `interactions.md`).
7. Update the Per-Agent Totals table in `interactions.md` to reflect the reconciled counts.

#### Planning Stage completion gate — MUST

The Planning Stage is NOT complete — and the orchestrator MUST NOT proceed to Step 6 (Transition) — until `<issue-folder>/planning-complete.md` exists, was written by the orchestrator as the final action of Step 5, and lists every required artifact as `[x]` with a verifying tool call (read or ls). This mirrors the @tester gate pattern: claims of completion are not trusted; the artifact must exist on disk and the verification must be a tool call, not narration. If `planning-complete.md` is missing or any item is `[ ]`, treat the planning stage as PARTIAL and complete the missing step(s) before proceeding. **Each `[x]` line must cite the canonical SKILL-prescribed path under `<issue-folder>`; an existence-only verification that does not bind the file to its canonical path is invalid and the line MUST remain `[ ]` until the file is at the correct path.**

### Step 6: Transition

On approval:
1. Produce a post-planning retrospective using the `telamon.retrospective` skill.
2. Address retrospective findings using the `telamon.address_retro` skill — pass the retro file path.
3. Proceed to implementation using the `telamon.implement_story` skill.

## Backlog Rules

- Known bugs discovered during planning must have product cost/benefit evaluation before being marked out of scope. Justify why incorrect output is acceptable, or include the bug in the backlog.
- When an issue requires sorting a collection, specify the sort key and justify why it matches the algorithm's invariant.
- When a use case returns data to presentation, specify an application-layer DTO — name the class and fields. Domain entities must not cross the application-to-presentation boundary.
- For refactoring issues, include an acceptance criterion: "The refactored code must produce byte-identical output to the original for the same input."
- When an issue involves building URLs from user-supplied or external input, include an acceptance criterion requiring URL encoding on interpolated segments.
- When the project has a `composer.json`, include an Issue 0 acceptance criterion verifying the package name follows `vendor/package-name` format (lowercase, hyphens only).

## Post-Planning

When planning is complete, follow the `telamon.remember_task` skill to document lessons learned:
- Reusable questions and answers from interactions with Architect, Critic, and human stakeholder
- Architecture decisions clarified during planning
- Domain knowledge uncovered during requirements refinement
