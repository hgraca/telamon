---
name: telamon.improve-planning
description: "Drives a continuous improvement loop for the multi-agent planning system. Generates a plan in an isolated task-solver session, evaluates it from the main session against absolute quality criteria, traces every weakness back to a specific instruction gap, and proposes edits to the agent files (telamon, po, architect, critic) and their planning skills (`plan_story`, `plan_implementation`, `review_plan`). Use when the user says "improve planning", "improve planning instructions", "planning quality", or wants to make the planning workflow produce better plans. Also use after a planning iteration completes poorly."
---

# Improve Planning Instructions

Drives a continuous improvement loop for the multi-agent planning system. Generates a plan in an isolated task-solver session, evaluates it from the main session against absolute quality criteria, traces every weakness back to a specific instruction gap, and proposes edits to the agent files (telamon, po, architect, critic) and their planning skills (`plan_story`, `plan_implementation`, `review_plan`). Use when the user says "improve planning", "improve planning instructions", "planning quality", or wants to make the planning workflow produce better plans. Also use after a planning iteration completes poorly.

## Architecture: Two Sessions

To avoid context contamination between solver and evaluator, this skill runs across **two distinct sessions**:

| Session                     | Role                                             | What it sees                                                                                                   |
|-----------------------------|--------------------------------------------------|----------------------------------------------------------------------------------------------------------------|
| **Main session** (this one) | Evaluator + orchestrator of the improvement loop | The artifacts produced by the task-solver session, prior reports — never the task-solver's working memory      |
| **Task-solver session**     | Runs the planning workflow against the kata      | Only the kata description and the current agent instructions — no prior iterations, no RCAs, no proposed fixes |

The main session is responsible for: setup, evaluation, root-cause analysis, proposing changes, applying approved changes, and looping. The task-solver session is responsible for: producing the plan exactly as a normal user request would.

The task-solver session runs in a regular folder (not a git repository). No git operations occur inside the iteration folder. The orchestrator's commit and "verify @tester gate" rules from `src/agents/telamon.md` are explicitly suspended in the solver session via PROMPT.md.

The grader is the **main-session telamon agent itself**. It evaluates the solver's artifacts using the absolute rubric defined below. There is no separate grading subagent.

### Scope of edits

**Only four agents and three skills are in scope** for instruction improvements, because only these participate in producing the plan:

| Agents                   | Skills                |
|--------------------------|-----------------------|
| `telamon` (orchestrator) | `plan_story`          |
| `po`                     | `plan_implementation` |
| `architect`              | `review_plan`         |
| `critic`                 |                       |

`developer`, `reviewer`, and `tester` are **out of scope** because no implementation runs in this iteration — Phase 1 stops at FINAL plan. Their instructions affect implementation quality, not plan quality.

### Task constancy

The task is **always** the Poke API kata at `references/poke-api-kata/`. Holding the task constant is what makes grade deltas across iterations meaningful. **If the kata changes, prior iterations are no longer comparable** — restart from iteration 1.

---

## Workflow

### Step 0: Verify previous iteration's edits are committed

Performed in the **main session**, *before* invoking the setup script.

Approved planning improvements are applied and committed at the **end of Step 7** of the iteration that produced them (not at the start of the next iteration). Step 0 is therefore a verification gate, not an application step:

1. Locate the previous iteration's `approved-changes.md` (`storage/self-improvement/improve-planning/iteration-<n-1>/approved-changes.md`). If none exists (first iteration, or no approvals), skip the rest of Step 0.
2. Confirm it has an "Applied" footer with a commit SHA.
3. Run `git log --oneline -1 <SHA>` to verify the commit exists in the current branch's history.
4. If the footer is missing or the commit cannot be found, the prior iteration was not closed correctly — stop and ask the user how to resolve (re-apply, skip, or abort iteration N).

If everything checks out, proceed to Step 1.

### Step 1: Run the setup script

**First, ask the user which model to test this iteration.** Show the current default (the top-level `model` in the workspace `opencode.jsonc`) and the previous iteration's model (if any) so the user can decide whether to repeat or change. Warn that changing the model invalidates grade comparisons against prior iterations and the iteration must be tagged `model-change`.

Once the user picks a model, invoke the setup script with the model as the first argument — the script owns iteration-folder creation, project init, and applying the model to the planning agents:

```bash
bash src/skills/self-improvement/improve-planning/scripts/setup-iteration.sh "<chosen-model-id>"
```

The script will:

1. Determine the next iteration number under `storage/self-improvement/improve-planning/`.
2. Copy `references/poke-api-kata/` into `iteration-<n>/`.
3. **Initialise the iteration folder as its own git root** (`git init` inside `iteration-<n>/`). This is required so opencode's config discovery stops at the iteration folder and does NOT walk up and merge every outer `opencode.jsonc` (which would poison the session with secret references that don't resolve).
4. Run `telamon init` against the iteration folder with project-side memory ownership (`TELAMON_MEMORY_OWNER=project`).
5. Materialise `iteration-<n>/opencode.jsonc` (replace the symlink with a real file).
6. Apply the model passed as `$1` to the four planning agents (`telamon`, `po`, `architect`, `critic`) in the iteration's `opencode.jsonc`. (If no argument is given AND stdin is a TTY, the script falls back to prompting the user; if no argument AND no TTY, the script fails loudly.)
7. **Materialise the symlinked `.opencode/agents/telamon/` directory into a real directory of copies, then rewrite the `model:` frontmatter on the four planning agents to the chosen model.** This is required because the agent-file frontmatter `model:` overrides the `agent.<name>.model` setting in `opencode.jsonc`, and the symlink target lives in the shared `src/agents/` tree (we must not edit it globally).
8. Print instructions for the user to start a new opencode session inside the iteration folder.

#### Setup script failure recovery

If the script fails partway through:

1. **Diagnose and fix** the immediate cause (missing dependency, permission issue, malformed JSONC, etc.).
2. **Roll back the partial iteration folder**: `rm -rf storage/self-improvement/improve-planning/iteration-<n>/` so a retry starts clean.
3. **Re-run the script** from scratch.
4. **If you cannot diagnose or fix** the failure, stop and ask the user for instructions before doing anything else. Do not leave a partial iteration folder behind.

After the script succeeds, write `iteration-<n>/metadata.json`:

```json
{
  "iteration": <n>,
  "timestamp": "<ISO 8601>",
  "model": "<chosen model id>",
  "rubric_version": "<version from this file>"
}
```

**Warn the user** if the chosen model differs from the previous iteration — grade deltas across model changes are not meaningful and the iteration must be tagged `model-change` in the tracker.

### Step 1.5: Task-solver session runs

The user opens a new opencode session in `iteration-<n>/` and tells the agent: *"Execute the instructions in PROMPT.md"*. That prompt instructs the solver to run Phase 1 (planning only — no implementation) and Phase 2 (write `interactions.md`) end-to-end **without asking the human stakeholder for approvals**. When the solver finishes, it instructs the user to return to the main session and say "evaluate this iteration".

The solver follows the standard `plan_story` workflow, which creates a normal **issue-folder** under:

```
iteration-<n>/.ai/telamon/memory/work/active/<YYYYMMDD-HHMMSS-NN>-<slug>/
```

This issue-folder is referred to below as `<issue-folder>`. Locate it by globbing `iteration-<n>/.ai/telamon/memory/work/active/*/` — there should be exactly one match. If there are zero or more than one, treat as a solver failure (record in `iteration-<n>/handoff-failure.md`).

The required artifacts inside `<issue-folder>` after the solver finishes:

- `backlog.md`
- `PLAN-ARCH-*.md` (architect's combined architecture spec + implementation plan)
- `PLAN-REVIEW-*.md` (critic review)
- `summary.md` (planning summary)
- Any UI/UX specs
- `interactions.md`

Main-session evaluation artifacts (`metadata.json`, `quality-report.md`, `root-cause-analysis.md`, `proposals.md`, `approved-changes.md`, `handoff-failure.md`) live at the **iteration root** (`iteration-<n>/`), NOT inside `<issue-folder>`.

**Failure path**: If the task-solver session fails to produce required artifacts (planning loops, agents stall, errors, or no `<issue-folder>` was created), record the failure in `iteration-<n>/handoff-failure.md` and treat that as the iteration's data — diagnose the failure as an instruction gap (e.g., "telamon doesn't know how to recover when critic returns no feedback"). Do not retry the task in the same iteration. Failed iterations are kept (not deleted) and counted as data points; mark them in the tracker with `status: failed`.

### Step 2: Gather Comparison Inputs

Back in the main session:

1. **Solver artifacts** — locate `<issue-folder>` (single match for `iteration-<n>/.ai/telamon/memory/work/active/*/`) and confirm every required file from Step 1.5 exists inside it (used by Steps 3 and 4).
2. **Reference standards** — architecture rules, the `plan_story` skill, the `plan_implementation` skill (used by Steps 3 and 4).
3. **Previous iteration data** — `iterations_quality.md`, prior `quality-report.md` and `root-cause-analysis.md` (used by Steps 5 and 6 for delta and regression analysis; skip for iteration 1).
4. **Rejected proposals log** — `storage/self-improvement/improve-planning/rejected-proposals.md` (used by Step 7 to suppress re-proposals).

### Step 3: Produce the Quality Report

Write `iteration-<n>/quality-report.md` following the Plan Quality Report Guide below. Grades are **absolute** — measured against the reference standards (architecture rules, the `plan_story` and `plan_implementation` skills, coding standards), not relative to any prior iteration.

The grader is the **main-session telamon agent**. Read the plan artifacts, the reference standards, this skill's grading rubric, and the example report at `src/skills/self-improvement/improve-planning/references/report-example.md` (used as a *format* reference only, not as a scoring anchor).

#### Solver-execution metrics

In addition to the rubric scores, extract the following objective metrics from `interactions.md` and record them in the quality report's Section 0 (Metrics):

| Metric                    | Source                                                                                                               |
|---------------------------|----------------------------------------------------------------------------------------------------------------------|
| Planning duration         | Wall-clock time between first agent invocation and final plan handoff                                                |
| Agent invocations (total) | Count of all subagent calls during planning                                                                          |
| Stall count               | Times the workflow had to be unblocked or restarted                                                                  |
| NEEDS_INPUT signals       | Times the solver agent asked the human stakeholder a question (should be 0 in this kata since approvals are skipped) |
| Critic rounds             | Number of architect↔critic exchanges before plan went FINAL                                                          |
| Required-artifact gaps    | Missing files from the required-artifacts list (Step 1.5)                                                            |

These metrics feed the "Solver execution" rubric dimension (see below).

#### Report validation

Before saving, verify the report:

- Has all 7 sections with correct numbering (0 Metrics, 1 Positives, 2 Negatives, 3 Regressions, 4 Things to Improve, 5 Instructions to Change, 6 Grade, 7 Grade Justification)
- Every Negative has Problem / Impact / Fix
- Grade table dimension weights sum to 100%
- Weighted total math is correct

If the report fails validation, fix it before proceeding to Step 4. Do not produce an RCA against a malformed report.

### Step 4: Root-Cause Analysis

Write `iteration-<n>/root-cause-analysis.md`. For each weakness in the quality report, produce a structured RCA block:

```markdown
### RCA-<n>: <Weakness title from quality report>

| Field                    | Value                                                                                       |
|--------------------------|---------------------------------------------------------------------------------------------|
| **Quality report ref**   | Section 2.X                                                                                 |
| **Dimensions affected**  | One or more of the rubric dimensions                                                        |
| **Responsible agent**    | Which agent should have caught/prevented this (must be telamon/po/architect/critic)         |
| **Instruction file**     | Exact path to the file with the gap                                                         |
| **Gap type**             | Missing rule / Ambiguous rule / Contradictory rule / Rule in wrong location                 |
| **Current text**         | Quote the relevant section (or "absent")                                                    |
| **Required text**        | What the instruction should say                                                             |
| **Consistency check**    | List any other files/skills that already cover this topic. Confirm the required text does NOT contradict them; if it would, the fix must update those files too. |
| **Regression risk**      | Could fixing this break something else? What?                                               |
| **Previously rejected?** | Search `rejected-proposals.md` by **target file + section** (not by exact text). If a prior rejection covers the same file+section AND the rejection reason still applies, mark "skip" and explain. Otherwise mark "no" or "supersedes prior rejection because <new evidence>". |
```

A single weakness may affect multiple rubric dimensions — list all of them in "Dimensions affected".

### Step 5: Regression and Effectiveness Check

**Skip this step for iteration 1** (no prior iteration to compare against).

Compare this iteration against the previous one:

- **Regression**: A previous positive (1.X) is now a negative. Identify which approved change in iteration `<n-1>` likely caused it.
- **Ineffective fix**: A previous negative persists despite an approved change targeting it. The change didn't work.
- **Effective fix**: A previous negative is gone. Note which approved change caused it — this builds evidence about what kinds of edits work.

**Comparison validity**: skip the entire step (and tag the iteration accordingly) if any of the following changed since the previous iteration:

- Model (`metadata.json.model`)
- Rubric version (`metadata.json.rubric_version`)
- The kata under `references/poke-api-kata/` (any change invalidates the entire history — restart from iteration 1)

Add a `## Regressions and Fix Effectiveness` section to the quality report. If skipped, record the reason in that section ("comparison invalidated by model change", etc.).

### Step 6: Update Iterations Tracker

**Skip the delta column for iteration 1** (no prior to subtract from). All other columns apply.

In `storage/self-improvement/improve-planning/iterations_quality.md`, append to the summary table. Use this exact header (initialise the file with this header if it doesn't exist):

```markdown
| Iter | Status | Model | Rubric | Grade | Δ Grade | Issues addressed | Issues remaining | Regressions | Effective fixes | Stalls | Critic rounds |
|------|--------|-------|--------|-------|---------|------------------|------------------|-------------|-----------------|--------|---------------|
```

- Status: `success` | `failed` | `model-change` | `rubric-change`
- Model and Rubric flagged with ⚠️ if changed from prior iteration
- Δ Grade: blank for iteration 1 and for iterations following any flagged change

Per-iteration narrative below the table:

- Grade
- Reflection (link to `interactions.md`, RCA, quality report)
- Issues addressed
- Issues remaining
- Regressions and root-cause-of-regression
- Lessons about which kinds of instruction edits work

### Step 7: Propose Instruction Improvements

Write `iteration-<n>/proposals.md`. For each proposal:

- **File**: exact path (must be one of: `src/agents/{telamon,po,architect,critic}.md`, `src/skills/workflow/plan_story/SKILL.md`, `src/skills/workflow/plan_implementation/SKILL.md`, `src/skills/workflow/review_plan/SKILL.md`)
- **Location**: section name or line reference
- **Before**: quote current text (or "absent")
- **After**: proposed text
- **Rationale**: which weakness this prevents and why
- **Regression risk**: what could go wrong
- **Linked RCA**: `RCA-<n>`

**Skip** any proposal whose RCA's "Previously rejected?" check returned "skip".

#### Presenting proposals to the user

To prevent unbounded approval loops:

1. **Total proposals per iteration**: cap at **3-5 highest-impact items**. The evaluator selects them by expected lift (estimated rubric-point gain × confidence). Proposals beyond the cap are dropped, not deferred — if a low-impact gap matters, it will resurface in a future iteration's evidence. Document dropped proposals in the RCA file (so future iterations can see they were considered) but do not present them to the user.
2. **Batch size**: present proposals in a single batch of at most 5 (the cap above ensures this is always feasible). Capture decisions before closing.
3. **Per-proposal decision**: each proposal gets one of `approved`, `rejected (<reason>)`, or `modified (<new text>)`.
4. **Override**: the user may say "approve all" or "reject all" as a shortcut.

There is no `defer` option. Every proposal must resolve to approved/rejected/modified in the iteration that produced it. Undecided proposals at end-of-batch are treated as rejected (with reason "no decision before batch close").

Record decisions:

- **Approved** → write to `iteration-<n>/approved-changes.md`.
- **Rejected** → append to `storage/self-improvement/improve-planning/rejected-proposals.md` with target file, target section, full text, user's reason, iteration number. Future iterations match by **file + section** (not exact text), see RCA "Previously rejected?" check.
- **Modified** → record the modified text in `approved-changes.md`. Also log in `rejected-proposals.md` referencing the original (file + section + "modified — see iteration N approved-changes.md").

#### Apply and commit (end of Step 7)

After all decisions are captured, the orchestrator MUST apply the approved/modified edits to the source files in this same session, then commit them in a single commit:

1. **Audit cross-cutting impact** — when an approved change renames a file or symbol referenced elsewhere (e.g., changing `PLAN.md` to `PLAN-ARCH-*.md`), grep the entire `src/` tree for stale references and update them in the same edit pass. Consistency across the codebase is a hard requirement; the "scope of edits" table is a suggestion for *where defects originate*, not a fence around *where fixes go*.
2. **Apply the edits** in the order recorded in `approved-changes.md` (foundational rules first; rules that depend on them after; renames last because they have the widest blast radius).
3. **Verify the working tree** — `git status` should show only files in scope. If anything unexpected appears, abort the commit and resolve before continuing.
4. **Single commit** — stage exactly the files touched by the approved edits and commit with message:
   ```
   chore(planning): apply iteration-<n> approved planning improvements

   <one-line summary per approved change, referencing iteration-<n>/approved-changes.md>
   ```
   Do NOT amend a previous commit. Do NOT push. The user pushes when they choose to.
5. **Update `approved-changes.md`** — append an "Applied" footer with the commit SHA and the list of files actually touched (which may exceed the proposals' enumerated targets due to the cross-cutting audit in step 1).

### Step 8: Decide Whether to Continue

Evaluate stopping criteria and report the decision:

| Condition                                       | Action                                                                                      |
|-------------------------------------------------|---------------------------------------------------------------------------------------------|
| Grade ≥ 95                                      | Suggest stopping — diminishing returns likely                                               |
| Grade delta < 2 for two consecutive iterations  | Suggest stopping — plateau reached                                                          |
| User says "done" or "stop"                      | Stop                                                                                        |
| Regressions > effective fixes in this iteration | Pause — recommend reverting last changes; ask user to confirm before next iteration         |
| Model changed mid-loop                          | Tag iteration `model-change`; do not compute delta; warn user the comparison is invalidated |
| Rubric version changed                          | Same as model change — tag, no delta, warn                                                  |
| Kata changed                                    | Stop the loop. Restart from iteration 1                                                     |
| Otherwise                                       | Schedule next iteration — user starts a new task-solver session and the loop continues      |

### Step 9: Periodic Reviews (every 5 iterations)

Every 5 iterations, the main session prompts the user with two reviews:

**Rubric review**: "Review the rubric? Look for: dimensions where every iteration scores the same (non-discriminating), dimensions whose weights no longer match what we care about, missing dimensions for failure modes we keep hitting."

Update the rubric only with explicit user approval. When changed:

1. Bump the `rubric_version` value in this file (e.g., `v1` → `v2`) and rewrite the rubric.
2. All future iterations record the new `rubric_version` in `metadata.json`.
3. Subsequent iterations cannot compute deltas against pre-change iterations (handled by Step 5's validity rules).

**Lessons consolidation**: Read the per-iteration narratives from `iterations_quality.md` (last 5 iterations). Extract recurring patterns about which kinds of instruction edits work and which don't. Append a dated entry to `storage/self-improvement/improve-planning/lessons.md` with the consolidated findings. This prevents lessons from being lost in scattered narratives.

---

## Plan Quality Report Guide

Use this guide to produce comparable quality reports for implementation plans.

**Rubric version**: `v2`

### Report Structure

Every report MUST use this exact structure:

```markdown
# Quality Report: <plan-name> (Iteration <N>)

## Purpose
<1–3 sentences: what the plan is for, which LLM(s) it targets, any known execution results>

---

## 0. Metrics
<Solver-execution metrics extracted from interactions.md — see Step 3 table>

## 1. Positives
<Numbered subsections (1.1, 1.2, ...) — one per strong point>

## 2. Negatives
<Numbered subsections (2.1, 2.2, ...) — one per weak point, each with Problem/Impact/Fix>

## 3. Regressions and Fix Effectiveness
<Comparison vs previous iteration — regressions, ineffective fixes, effective fixes. Omit section for iteration 1 or when comparison is invalidated; in the latter case state the reason here.>

## 4. Things to Improve
<Prioritized list of changes that would raise the grade>

## 5. Instructions to Change
<Concrete edits to specific files, with before/after or proposed additions>

## 6. Grade
<Dimension table + weighted total>

## 7. Grade Justification
<"Why not higher" + "Why not lower" — connects deductions to specific evidence>
```

### Evaluation Dimensions

Score each dimension 0–100, then compute the weighted total.

| Dimension                           | Weight | What to evaluate                                                                                                                                                             |
|-------------------------------------|--------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Specificity & completeness**      | 25%    | Does every task have testable ACs? Are file paths, class names, field types, and behaviors explicit? Would a lower-reasoning LLM need to guess anything?                     |
| **`plan_story` / `plan_implementation` compliance** | 15%    | Does the plan satisfy every rule in the `plan_story` and `plan_implementation` skills? Check each bullet point with line references. |
| **Architecture correctness**        | 15%    | Does the plan match the architecture rules? Directory structure, dependency rules, naming conventions. Is there an architect review confirming this?                         |
| **Clarity for lower-reasoning LLM** | 20%    | Are rules centralized or scattered? Are implicit assumptions made? Would a model with limited context window find all necessary information within the task it's working on? |
| **Process guidance**                | 10%    | Does the plan address: reviewer frequency, commit strategy, stall recovery, delegation batch size, error escalation?                                                         |
| **Defensive completeness**          | 10%    | Does the plan account for all coding-standard rules? Are edge cases and known pitfalls addressed?                                                                            |
| **Solver execution**                | 5%     | Objective metrics from Section 0: low stall count, low critic rounds, no NEEDS_INPUT, no required-artifact gaps. Score 100 if all metrics are at their best; deduct for stalls, missing artifacts, excessive critic rounds (>3), any NEEDS_INPUT signal. |

Weights sum to 100%.

### Computing the Final Grade

```
Grade = Σ (dimension_weight × dimension_score)
```

Round to the nearest integer.

### Writing Negatives

For each negative, use this format:

```markdown
### 2.N <Title> (-X points)

**Problem:** <What rule or standard is violated or missing. Reference the source document.>

**Impact:** <What failure this caused or could cause in implementation.>

**Fix:** <Concrete change to the plan that would resolve this.>
```

Point deductions are relative to the dimension they affect:
- Missing rule affecting ALL tasks: -2 to -4 points
- Missing rule affecting ONE task: -0.5 to -1 point
- Ambiguity that could be misinterpreted: -1 to -2 points
- Process gap with proven impact: -2 to -3 points

### Scoring Guidelines — What 100 Looks Like

| Dimension                       | 100/100 means                                                                                          |
|---------------------------------|--------------------------------------------------------------------------------------------------------|
| Specificity & completeness      | Every class, method, field, behavior, and file path is named. Zero ambiguity. Edge cases enumerated.   |
| `plan_story` / `plan_implementation` compliance | Every rule in both skills satisfied with traceable evidence.                                          |
| Architecture correctness        | Architect review confirms compliance. Directory tree matches architecture exactly.                     |
| Clarity for lower-reasoning LLM | All rules centralized. Each task's AC is self-contained. No implicit knowledge required.               |
| Process guidance                | Reviewer mandate, commit strategy, stall recovery, delegation limits, error escalation — all explicit. |
| Defensive completeness          | Every coding-standard rule reflected. Known pitfalls addressed. All edge cases have test criteria.     |
| Solver execution                | Zero stalls, zero NEEDS_INPUT, ≤3 critic rounds, all required artifacts present.                       |

### Comparability Rules

1. Always use the same 7 dimensions with the same weights (until rubric review in Step 9 changes them, in which case bump rubric version)
2. Always use the same point-deduction scale
3. Always reference the same standard documents
4. Always end with a single integer grade
5. Never grade on effort or length
6. Grade the plan as written, not as intended — if a rule is implied but not stated, it's a gap

---

## Storage Layout

```
storage/self-improvement/improve-planning/
├── iterations_quality.md           # Cross-iteration tracker
├── rejected-proposals.md           # User-rejected proposals (don't re-propose; matched by file+section)
├── lessons.md                      # Consolidated learnings (updated every 5 iterations)
└── iteration-<n>/
    ├── metadata.json               # Main session: iteration, timestamp, model, rubric_version
    ├── handoff-failure.md          # Main session: only if task-solver failed
    ├── quality-report.md           # Main session output
    ├── root-cause-analysis.md      # Main session output
    ├── proposals.md                # Main session output
    ├── approved-changes.md         # Main session: user-approved subset (applied & committed at end of Step 7)
    └── .ai/telamon/memory/work/active/<YYYYMMDD-HHMMSS-NN>-<slug>/  # Solver issue-folder
        ├── backlog.md              # Solver output
        ├── PLAN-ARCH-*.md          # Solver output (combined architecture spec + implementation plan)
        ├── PLAN-REVIEW-*.md        # Solver output (critic review)
        ├── summary.md              # Solver output (planning summary)
        └── interactions.md         # Solver output (from template)
```

**Retention**: failed iterations (with `handoff-failure.md`) are kept indefinitely as data points. They are *never* auto-deleted. If you need to free space, archive them under `storage/self-improvement/improve-planning/archive/iteration-<n>/` manually.

---

## Checklist Before Submitting an Iteration

This checklist is a **mandatory gate**. Before declaring iteration N complete and moving to Step 8, verify every item. If any item fails, fix it before proceeding. Record completion of this checklist as the final entry in the iteration's quality report (a single line: `Checklist: passed at <ISO 8601>`).

- [ ] Iteration number determined (max existing + 1)
- [ ] Approved changes from previous iteration applied (or recovery path executed)
- [ ] Setup script ran cleanly (or rolled-back partial folder before retry)
- [ ] `metadata.json` records iteration, timestamp, model, rubric version
- [ ] User warned if model or rubric version changed
- [ ] Task-solver session ran in isolation
- [ ] Solver `<issue-folder>` located (single match for `iteration-<n>/.ai/telamon/memory/work/active/*/`)
- [ ] All required solver artifacts present in `<issue-folder>` (`backlog.md`, `PLAN-ARCH-*.md`, `PLAN-REVIEW-*.md`, `summary.md`, `interactions.md`)
- [ ] Quality report has all 8 sections (0–7) with correct numbering
- [ ] Section 0 (Metrics) populated from `interactions.md`
- [ ] Every negative has Problem/Impact/Fix
- [ ] Grade table sums to 100% weights
- [ ] Weighted total math is correct
- [ ] Report passed validation (Step 3 sub-step) before RCA was started
- [ ] Root-cause analysis written, one structured RCA per weakness
- [ ] RCA "Responsible agent" is one of telamon/po/architect/critic
- [ ] RCA "Dimensions affected" lists all rubric dimensions impacted by the weakness
- [ ] RCA "Consistency check" performed for every proposed required text
- [ ] RCA "Previously rejected?" matched by file+section, not exact text
- [ ] Regression and effectiveness check performed (skipped only for iteration 1 or invalidated comparisons; reason recorded)
- [ ] Iterations tracker updated; delta blank for iteration 1 and for iterations following any flagged change
- [ ] Proposals only target in-scope files (telamon/po/architect/critic agents + plan_story/plan_implementation/review_plan skills)
- [ ] Proposals exclude items previously rejected (per `rejected-proposals.md` file+section match)
- [ ] Each proposal has before/after, rationale, regression risk, linked RCA
- [ ] Proposals presented in batches of ≤5
- [ ] User decisions recorded: approved → `approved-changes.md`, rejected → `rejected-proposals.md`
- [ ] Stopping criteria evaluated and reported
- [ ] If iteration is multiple-of-5: rubric review prompt offered AND lessons consolidated into `lessons.md`
