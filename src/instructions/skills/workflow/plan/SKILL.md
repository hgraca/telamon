---
name: telamon.plan
description: "Plans work of any size. Detects whether the stakeholder brief is a list of stories (epic path), a single brief judged trivial (skip planning), or a single brief needing a plan (story path). Use when a human stakeholder provides a story, epic, feature request, or business initiative that needs planning before implementation."
---

# Skill: Plan

Plan body of work. Inspect prompt, route to one of three paths:

| Path        | Trigger                                                                            | Output                                                 |
|-------------|------------------------------------------------------------------------------------|--------------------------------------------------------|
| **Epic**    | Prompt contains explicit list of stories, is cross-cutting, or multi-step workflow | Epic backlog + per-story sub-folder w/ full story plan |
| **Trivial** | 1-3 files changed, clear scope, no ambiguity                                       | None. Go straight to `telamon.implement_story`         |
| **Story**   | Default for any single non-trivial brief                                           | Backlog + PLAN-ARCH + critic review + optional UI/UX   |

## When to Apply

- Human stakeholder give story, epic, feature request, business initiative
- `/plan` command invoked
- Planning need before implementation

## Artifacts

Place all artifacts in single `<work-folder>` under `.ai/telamon/memory/work/active/`. Planning artifacts not committed to git.

### Folder naming

`.ai/telamon/memory/work/active/YYYYMMDD-HHMMSS-NN-<title_slug>/`

`YYYYMMDD-HHMMSS` = current UTC timestamp. `NN` = zero-padded sequential number. Check existing folders, use next available. Timestamp prefix order chronologically; sequence disambiguate same-second folders.

### Folder structure

**Story path** — all artifacts in `<work-folder>`:

```
.ai/telamon/memory/work/active/YYYYMMDD-HHMMSS-NN-<story_slug>/
  backlog.md
  PLAN-ARCH-YYYY-MM-DD-NNN.md
  PLAN-REVIEW-YYYY-MM-DD-NNN.md
  summary.md
  ...
```

**Epic path** — top-level folder hold epic backlog + summary; each story get sub-folder:

```
.ai/telamon/memory/work/active/YYYYMMDD-HHMMSS-NN-<epic_slug>/
  backlog.md                          # Epic backlog (stories, not tasks)
  summary.md                          # Epic planning summary
  YYYYMMDD-HHMMSS-NN-<story_slug>/    # One per story
    backlog.md                        # Story backlog (tasks)
    PLAN-ARCH-YYYY-MM-DD-NNN.md
    summary.md
    ...
```

### One folder per initiative — MUST

Each initiative MUST have exactly one folder. NEVER create second folder for same initiative. Story artifacts within epic go in sub-folders of epic folder.

### Scratch files

Use `telamon.thinking` skill for temp files. Promote useful findings from `thinking/` to brain or issue artifact before session close.

## Procedure

### Step 0: Pre-flight

1. Read brain/ notes per `telamon.recall_memories` skill. Include applicable lessons in all delegations.
2. **Check existing work folder**: List `.ai/telamon/memory/work/active/`. If folder match current initiative exist, reuse — NEVER create new. If multiple folders for same initiative, consolidate into correctly-named one, delete duplicate.

### Step 1: Detect prompt shape

Orchestrator judge prompt. NEVER delegate this. Use table:

| Prompt shape                                                                                                                                                        | Path    | Next   |
|---------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------|--------|
| Numbered/bulleted list of stories; OR `stories:`/`tasks:`/`features:` phrasing; OR NL enumeration of distinct features; OR is cross-cutting; OR multi-step workflow | epic    | Step 5 |
| 1-3 files changed, clear scope, no ambiguity                                                                                                                        | trivial | Step 2 |
| Any other single brief                                                                                                                                              | story   | Step 3 |

**List rule**: each list item MUST be candidate story (coherent feature/change), not sub-step of one story. Items reading as steps for one feature (e.g. "create model, write migration, add controller") = single story → story path.

**Ambiguous**: ask stakeholder — "One story or list of separate stories planned as epic?"

**Doubt rule**: prefer story path. Cost of unnecessary backlog small; cost of skip planning on ambiguous work large.

### Step 2: Trivial path

1. Skip backlog, arch spec, critic review entirely.
2. Hand brief + obvious context (file paths, patterns) directly to `telamon.implement_story` skill. Use `<work-folder>` as `<issue-folder>`.
3. `implement_story` cycle (Tester → Developer → Reviewer per task) provide rigor. No planning artifacts produced.
4. Skip Steps 3–8.

### Step 3: Story path — Create backlog

Delegate @po. First sentence MUST be: `Write <work-folder>/backlog.md containing the prioritized task list with acceptance criteria for: <story brief>.`

- PO apply backlog rules from `src/instructions/agents/po.md` when writing tasks.
- PO save to `<work-folder>/backlog.md`, signal FINISHED with path.
- PO signal NEEDS_INPUT → relay to stakeholder, re-delegate w/ answer.

### Step 4: Story path — Architecture and implementation plan

Delegate @architect. First sentence MUST be: `Write <work-folder>/PLAN-ARCH-YYYY-MM-DD-NNN.md containing the architecture spec and implementation plan for: <work-folder>/backlog.md.`

- Architect produce concrete directory tree mapping every source file to assigned path.
- Architect produce **single** `<work-folder>/PLAN-ARCH-YYYY-MM-DD-NNN.md` containing BOTH arch spec + impl plan. NEVER split into separate `ARCH-*.md` and `PLAN-*.md`. Internal structure defined in `telamon.plan_implementation` skill; architect deliverable contract in `src/instructions/agents/architect.md`.
- Architect signal FINISHED with path. Orchestrator route to @critic in Step 6.

#### Spike-during-planning rule

When plan depend on third-party API capability (plugin hooks, SDK features, undocumented runtime behavior) AND brain/ notes NOT confirm capability: instruct architect run verification spike DURING planning, NEVER as Task 0 of implementation. Spike in backlog = unverified arch + carried fallback design through review. Skip rule only when architect cite brain/ note (gotcha, ADR, pattern) confirming capability.

#### UI/UX review (if applicable)

UI work need → delegate @ui-designer and/or @ux-designer. First sentence MUST be: `Write <work-folder>/UI-YYYY-MM-DD-NNN.md ...` (or `UX-YYYY-MM-DD-NNN.md`).

- UI Designer save to `<work-folder>/UI-YYYY-MM-DD-NNN.md`, signal FINISHED.
- UX Designer save to `<work-folder>/UX-YYYY-MM-DD-NNN.md`, signal FINISHED.

Skip if no UI component.

### Step 5: Epic path — Write epic backlog and plan each story

Prompt contain list, is cross-cutting, or multi-step workflow → epic path.

1. Delegate @po. First sentence MUST be: `Write <work-folder>/backlog.md containing the epic-level story breakdown for: <stakeholder list>.`
   - Epic backlog: **one entry per story from user list**. NEVER regroup, split, merge — preserve user structure.
   - Each entry: title, description (one paragraph), priority, dependencies on other stories in list, sub-folder slug to create.
   - PO save to `<work-folder>/backlog.md`, signal FINISHED with path.

2. For each story in epic backlog, priority order:
   1. Create story sub-folder: `<work-folder>/YYYYMMDD-HHMMSS-NN-<story_slug>/`
   2. Recurse **story path** (Steps 3–6) for story plan. Use sub-folder as `<work-folder>` for recursion.
   3. Output progress report after each story:
      > **Epic planning progress**: \<planned\>/\<total\> stories planned | \<remaining\> remaining

All stories MUST be planned before implementation begin. Make cross-story dependencies + arch concerns visible before code.

After all stories planned, **epic-level architecture review**:

1. Delegate @architect to review full epic — all story backlogs + arch specs together.
2. Architect identify: shared abstractions, migration ordering, cross-story deps, integration risks.
3. Architect recommend changes → update affected story plans before proceed.

Skip Steps 3–4 + 6 at epic level (executed inside each story recursion). Continue Step 7.

### Step 6: Critic review loop

Delegate @critic. First sentence MUST be: `Write <work-folder>/PLAN-REVIEW-YYYY-MM-DD-NNN.md reviewing <work-folder>/PLAN-ARCH-YYYY-MM-DD-NNN.md and the backlog.`

- Critic save to `<work-folder>/PLAN-REVIEW-YYYY-MM-DD-NNN.md` per `telamon.review_plan` skill (NEVER use `CRITIC-*.md` prefix).
- Address necessary issues.
- Justify issues not addressed.
- After fixes, update `PLAN-ARCH-*.md` in place so directory tree, snippets, step list match revised backlog. Change `Status` from `DRAFT`/`IN REVIEW` to `FINAL` when critic loop conclude w/ zero BLOCKERs.
- Stall or goal shift → terminate loop, ask stakeholder for direction.
- Iterate until no issues remain.

#### Review/revision state-transition table — MUST

Planning state machine has exactly four legal transitions out of any critic verdict. Orchestrator MUST consult table after every critic round, select unique matching row. Any other transition invalid.

| Critic verdict         | Has unresolved findings? | Next state | Next delegation                                                     |
|------------------------|--------------------------|------------|---------------------------------------------------------------------|
| APPROVED               | No                       | FINAL      | (none — orchestrator promote per `telamon.md` FINAL-promotion gate) |
| APPROVED               | Yes (any severity)       | IN REVIEW  | architect (revision cycle for new findings)                         |
| CHANGES REQUESTED      | (always)                 | IN REVIEW  | architect (revision cycle for all findings)                         |
| CONDITIONALLY APPROVED | (always)                 | IN REVIEW  | architect (revision cycle for unmet conditions)                     |

**Forbidden transition (MUST NOT)**: Consecutive critic rounds without intervening architect revision. Previous round returned CHANGES REQUESTED, CONDITIONALLY APPROVED, or APPROVED-with-findings → orchestrator MUST delegate revision to architect before any further critic delegation. Critic invocation violating this rule invalid; output MUST NOT be merged into audit log without corresponding architect-revision Delegation entry preceding it. "Second opinion" review needed → architect MUST first produce Review Response section explaining why no changes need (count as intervening revision) before next critic round.

**Confirming-review feedback handling — MUST**: Confirming critic round (round after architect revision addressing prior BLOCKERs) may return verdict `APPROVED` while surfacing new findings (any severity, including MINOR). When happen, do NOT transition to `Status: FINAL`. Re-delegate architect for one resolution pass. Architect deliverable: updated `PLAN-ARCH-*.md` + addition to Review Response section that, for each new finding, record either:

- fix applied (cite line range or section), OR
- explicit dispensation (cite finding identifier + severity, one-line rationale).

After architect pass, orchestrator verify Review Response cover every new finding from confirming review, then transition to `Status: FINAL` without additional critic round (verdict already `APPROVED`; cycle only close per-finding ledger). Confirming review return `APPROVED` w/ zero new findings → transition direct to `Status: FINAL`. Rationale: confirming review whose new feedback receive no architect cycle = decorative; per-finding ledger is FINAL gate, gate meaningless if findings dropped.

### Step 7: Closing — Summary and approval

1. Create `<work-folder>/summary.md` per `telamon.summarize_plan` skill.
2. Format all markdown files in work folder: invoke `format-md` tool w/ `path: <work-folder>`.
3. Output summary to stakeholder, ask final approval.
4. Write `<work-folder>/planning-complete.md` as final closing-checklist artifact, listing each required artifact w/ **existence-verified AND canonical-path-verified** status. File MUST be orchestrator last write before reporting completion to stakeholder.

   Each `[x]` line MUST cite **canonical SKILL-prescribed path** under `<work-folder>` (resolved to absolute path of work folder created Step 0/1) AND **verifying tool call** confirming file at that path. Existence-only check not binding file to canonical path invalid — line MUST remain `[ ]` until file at correct path.

   Required artifacts by path:

   **Story path**:
   - `<work-folder>/backlog.md` — refined, every task has acceptance criteria + priority.
   - `<work-folder>/PLAN-ARCH-YYYY-MM-DD-NNN.md` — `Status: FINAL`, set by orchestrator only after critic round APPROVED.
   - `<work-folder>/PLAN-REVIEW-YYYY-MM-DD-NNN.md` — at least one w/ verdict APPROVED dated after latest architect revision.
   - `<work-folder>/summary.md` — per `telamon.summarize_plan` skill.
   - `<work-folder>/retrospective/planning.md` — per `telamon.retrospective` skill.

   **Epic path**:
   - `<work-folder>/backlog.md` — epic backlog, one entry per story from user list.
   - `<work-folder>/summary.md` — epic planning summary.
   - `<work-folder>/retrospective/planning.md` — per `telamon.retrospective` skill.
   - For each story sub-folder, **Story path** required artifacts above (verified inside sub-folder).

   **Trivial path**: No `planning-complete.md` produced. No planning stage. Proceed direct to implementation.

   For each artifact, orchestrator MUST `read` it at canonical path (or `ls` directory + confirm non-empty file at that path) BEFORE listing `[x]`. Listing without verification, or verification at non-canonical path, forbidden — proof is tool call against canonical path, not assertion.

   Verification format — each `[x]` line MUST take this shape:

   - [x] `<absolute-or-workspace-relative-canonical-path>` (verified by `<tool>` at `<ISO-8601 timestamp>` — `<evidence>`)

   Example body:

   ```markdown
   # Planning complete — 20260508-143000-01-pokeapi-bus-refactor

   Work folder: `.ai/telamon/memory/work/active/20260508-143000-01-pokeapi-bus-refactor/`
   Path: story
   Verified at: 2026-05-08T15:30:00Z

   - [x] `.ai/telamon/memory/work/active/20260508-143000-01-pokeapi-bus-refactor/backlog.md`
         (verified by `read` — 257 lines, 7 tasks across 5 phases)
   - [x] `.ai/telamon/memory/work/active/20260508-143000-01-pokeapi-bus-refactor/PLAN-ARCH-2026-05-08-001.md`
         (verified by `read` — Status: FINAL on line 4)
   - [x] `.ai/telamon/memory/work/active/20260508-143000-01-pokeapi-bus-refactor/PLAN-REVIEW-2026-05-08-002.md`
         (verified by `read` — verdict: APPROVED on line 3)
   ```

   Artifact NOT at canonical path → line is `[ ] <canonical-path> — NOT AT CANONICAL PATH (found at <actual-path>)` or `[ ] <canonical-path> — MISSING`. Orchestrator treat planning stage PARTIAL per closing gate below. Move file to canonical path, re-verify before mark `[x]`. Planning equivalent of @tester gate: planning stage complete only when this file exist + list every required artifact `[x]` at canonical path w/ verifying tool call.

#### Complete-side enumeration — MUST

Closing checklist + summary are sound-side AND complete-side. Sound-side (already established by canonical-path verification above): every listed artefact MUST exist on disk w/ verifying tool call. Complete-side (this rule): every produced artefact in work folder MUST appear in listing.

**Step 7 procedure addendum**:

1. Run `glob` for `PLAN-REVIEW-*.md` in `<work-folder>` (recursive in story sub-folders for epic path). Each match: closing checklist (`planning-complete.md`) + summary (`summary.md` Artifacts Produced table) MUST contain one entry naming file, its verdict (APPROVED / CHANGES REQUESTED / CONDITIONALLY APPROVED), one-line role (e.g. `superseded`, `latest-approved`, `confirming`, `orphan-investigation-required`).
2. Run `glob` for `PLAN-ARCH-*.md` in `<work-folder>` (recursive for epic path). Same rule (each file listed w/ status + role).
3. Run `glob` for any other `*.md` artefact in `<work-folder>` (backlog, summary, retrospective, scratch). Each MUST appear in closing checklist either as required artefact or as `not required by skill — present for context`.
4. Any glob match unlisted in `planning-complete.md` after step 1–3 → gate FAIL. Orchestrator MUST add missing entry (w/ role + verifying tool call) before proceed.

**Audit-log enumeration (MUST)**: `interactions.md` MUST contain one Delegation entry per producing subagent invocation:

- Each `PLAN-REVIEW-*.md` file in work folder → `interactions.md` MUST have ≥1 critic Delegation entry whose deliverable match file path.
- Each `PLAN-ARCH-*.md` file (+ each architect-revision recorded in Review Response section) → `interactions.md` MUST have ≥1 architect Delegation entry.
- Each backlog file → `interactions.md` MUST have ≥1 PO Delegation entry.

Produced deliverable w/ no corresponding Delegation entry → orchestrator MUST add missing Delegation entry before closing-checklist gate pass. Added entry MUST cite deliverable path as evidence, may use `RECONSTRUCTED FROM ARTEFACT` as recovery-method tag.

#### Per-Agent Totals reconciliation across all closing artefacts — MUST

Every agent-count claim in ANY closing artefact (`summary.md`, `retrospective/planning.md`, `retrospective/implementation.md`, `planning-complete.md`, and any other `<work-folder>/**/*.md` file produced at closing checklist stage) MUST reconcile against count of Delegation entries in `interactions.md` per agent role.

**Procedure**:

1. Compute `delegation_count[agent]` from `interactions.md` (one count per role: PO, architect, critic, tester, developer, reviewer, designer).
2. Compute `deliverable_count[agent]` from `glob` per agent expected deliverable filename pattern:
   - critic: `glob` for `PLAN-REVIEW-*.md` in `<work-folder>`.
   - architect: `glob` for `PLAN-ARCH-*.md` in `<work-folder>` PLUS count of architect-revision entries in any `Review Response` section.
   - PO: `glob` for `backlog.md` + any `backlog-delta-*.md` in `<work-folder>`.
   - Other agents: `glob` for agent expected deliverable filename pattern.
3. Confirm `delegation_count[agent] >= deliverable_count[agent]` for each subagent. Any agent `delegation_count < deliverable_count` → orchestrator MUST add missing Delegation entries — cite produced deliverable as evidence — before gate pass.
4. For each closing artefact in work folder, `grep` artefact for any agent-count claim (patterns: `\d+ (PO|architect|critic|tester|developer|reviewer|designer)`, `Total subagent invocations: \d+`, any cell in Per-Agent Totals table).
5. For every match, verify cited number equal `delegation_count[agent]` (or sum if claim is "Total"). Mismatches FAIL gate.
6. Orchestrator MUST update mismatched artefacts w/ reconciled counts, annotate reconstructed entries w/ `RECONSTRUCTED FROM ARTEFACT`, cite source-of-truth (delegation count from `interactions.md`).
7. Update Per-Agent Totals table in `interactions.md` to reflect reconciled counts.

#### Planning Stage completion gate — MUST

Planning Stage NOT complete — orchestrator MUST NOT proceed to Step 8 (Transition) — until `<work-folder>/planning-complete.md` exist, written by orchestrator as final action of Step 7, list every required artifact `[x]` w/ verifying tool call (read or ls). Mirror @tester gate pattern: claims of completion not trusted; artifact MUST exist on disk + verification MUST be tool call, NEVER narration. `planning-complete.md` missing or any item `[ ]` → treat planning stage PARTIAL, complete missing step(s) before proceed. **Each `[x]` line MUST cite canonical SKILL-prescribed path under `<work-folder>`; existence-only verification not binding file to canonical path invalid + line MUST remain `[ ]` until file at correct path.** Gate not apply to trivial path (no planning artifacts produced).

### Step 8: Transition

On approval:

1. Produce post-planning retrospective per `telamon.retrospective` skill.
2. Address retrospective findings per `telamon.address_retro` skill — pass retro file path.
3. Proceed to implementation:
   - **Story path**: follow `telamon.implement_story` skill once, w/ `<work-folder>` as `<issue-folder>`.
   - **Epic path**: follow `telamon.implement_story` skill for each story, dependency-respecting order, story sub-folder as `<issue-folder>`. After each story, output progress report:
     > **Epic implementation progress**: \<implemented\>/\<total\> stories done | \<blocked\> blocked | \<remaining\> remaining
   - **Trivial path**: already routed Step 2; nothing more here.

Ordering rules (epic path): respect explicit deps in epic backlog; no deps → priority order; foundation stories (shared domain, infra, config) before consumers; same bounded context → sequential.

#### Epic completion (when epic path taken)

All stories implemented:

1. Run full test suite to verify cross-story integration.
2. Produce post-epic retrospective per `telamon.retrospective` skill. Save to `<work-folder>/retrospective/implementation.md`.
3. Address retrospective findings per `telamon.address_retro` skill — pass retro file path.
4. Notify stakeholder w/ completion report covering all stories + recommended next actions.
5. Follow `telamon.remember_task` skill to capture lessons learned from epic.
6. Archive work folder: move `<work-folder>` from `.ai/telamon/memory/work/active/` to `.ai/telamon/memory/work/archive/`, preserve name.

## Exception Handling

- Unexpected situation → use `telamon.exception-handling` skill for structured recovery.
- Story cannot be planned or implemented due to dep on unfinished story → mark BLOCKED in epic backlog, continue w/ next eligible story.
- Orchestrator may terminate early: requirements change, work deprioritized, stakeholder request pivot.
- Scope grow during planning → pause, ask stakeholder whether to expand work or split off additional initiatives.
