# Quality Report: `.ai-kata-plan` (Backlog v10)

## Purpose

This plan (backlog + architect review + critic review) is designed to guide a **lower-reasoning LLM** through implementing a PokeAPI parser refactoring kata using Explicit Architecture (DDD + Hexagonal + CQRS). The plan was used by three different LLMs: Devstral 2 2512 (V10: 99/100, V11: 99.75/100) and DeepSeek V3 0324 (V12: 98.85/100).

---

## 1. Positives

### 1.1 Exceptional Specificity

- **Complete directory tree** with every file path explicitly mapped (lines 69–151). A developer agent never has to guess where a file goes.
- **Namespace mapping table** (lines 156–165): eliminates PSR-4 ambiguity entirely.
- **Data flow diagram** (lines 26–55): visual representation of the full pipeline from entry point to stdout.
- **Key Design Decisions section** (lines 168–181): explicitly resolves 14 architectural questions that would otherwise cause developer stalling or misinterpretation.

### 1.2 Comprehensive Acceptance Criteria

Each task has detailed, testable acceptance criteria. For example, Task 1 specifies:
- Exact VO behavior (trim, lowercase, non-empty validation)
- The `levelFor()` algorithm with all 4 edge cases enumerated
- A specific test case for the bug fix scenario
- Sorting invariant justified ("sort by experience because...")

This level of detail prevents a lower-reasoning LLM from making incorrect assumptions.

### 1.3 Lessons-from-Prior-Iterations Section

Lines 351–365 incorporate 15 concrete lessons from prior failures:
- PHPUnit 9→11 upgrade path
- Docker flags (`--rm` only, no `-it`)
- PHPStan-specific requirements (`\Closure` over `callable`, `JSON_THROW_ON_ERROR`)
- Handler naming conventions
- Generic PHPDoc annotations

This section directly prevents the most common failure modes observed in V1–V9.

### 1.4 PLANNING.md Full Compliance

| Rule | Status | Evidence |
|------|--------|----------|
| Sort key justification | ✅ | Line 222: "sorted by experience ascending... because `levelFor()` iterates comparing base_experience against each item's experience threshold" |
| Application-layer DTO specified | ✅ | Line 266: `PokemonLevelResult` with named fields |
| Output equivalence criterion | ✅ | Line 328: "byte-identical output to the original" |
| URL encoding requirement | ✅ | Line 282: `rawurlencode()` |
| Composer name format | ✅ | Line 195: `gete/poke-parser` (lowercase, hyphens) |
| Bug cost/benefit evaluation | ✅ | Lines 11–13: detailed analysis of the bug and README-input behavior |

### 1.5 Problem Analysis Quality

The bug analysis (lines 11–13) is excellent:
- Identifies the root cause (`$pokeLevel` only assigned inside `break`)
- Explains why README inputs don't trigger it (experience falls between thresholds)
- Explicitly states output will be byte-identical despite the fix

This prevents a developer from second-guessing whether the fix changes expected output.

### 1.6 Architecture Review Integration

The ARCH document (lines 1–130) provides:
- Confirmation that the directory tree matches ARCHITECTURE.md
- 10 explicit findings addressing potential concerns
- 7 developer guidelines as a quick-reference checklist

### 1.7 Critic Review Quality

The CRITIC document identifies real weaknesses (W1: ambiguous field naming) and provides actionable suggestions (S1: exit code testing, S3: Level(0) behavior confirmation). It validates all PLANNING.md rules with line references.

---

## 2. Negatives

### 2.1 Missing FQN Import Rule in Backlog (-3 points)

**Problem:** ARCHITECTURE.md line 119 states: "We import classes whenever possible, as opposed to using fully qualified names within the code. This applies to both production and test code."

The backlog only mentions this rule once, in Task 7 (line 347): "All `use` imports — no FQN (fully qualified names) in source or test code." However:
- It's buried in the last task's acceptance criteria
- Tasks 1–6 have no FQN-related acceptance criteria
- The Lessons section doesn't mention it

**Impact:** V12 ended up with 8 FQN occurrences in test files (-0.5 points). The rule was partially caught by the reviewer in Task 1 (production code was fixed), but test code written in Tasks 2–6 was never checked because the rule wasn't part of their acceptance criteria.

**Fix:** Add to each task's AC: "All files must use `use` imports — no fully-qualified class names (leading backslash). This applies to both source and test files." Or add it as a global constraint in the "Constraints" section.

### 2.2 No Explicit `final` Requirement for Test Classes (-2 points)

**Problem:** The backlog requires "All domain classes are `final readonly`" (line 228) and the Architect guidelines say "All classes `final`" (ARCH line 126). However, there is no explicit AC requiring test classes to be `final`.

**Impact:** V12's test classes are not `final` (-0.1 points). The developer followed the spirit of the rule for production code but not for tests.

**Fix:** Add to the Constraints section or Task 7 AC: "All test classes must be declared `final class`."

### 2.3 No Reviewer Frequency Mandate (-2 points)

**Problem:** The plan is silent on reviewer invocation frequency. IMPLEMENTATION.md requires per-task reviewer invocations (step 6.3), but the plan doesn't reinforce this. A PO operating under time pressure may skip reviews for "similar" tasks.

**Impact:** V12 only reviewed Task 1 of 8, missing FQN issues in later tasks (-0.25 points). The plan doesn't remind the PO that reviewing is mandatory per task.

**Fix:** Add a "Process Requirements" section to the backlog: "Each task must be reviewed by @reviewer before commit. Reviews must not be skipped even if prior tasks passed cleanly."

### 2.4 No Guidance for Developer Stalling (-1.5 points)

**Problem:** The plan doesn't address what to do when the developer agent stalls. IMPLEMENTATION.md has guidance (step 57–62), but a lower-reasoning PO agent may not refer back to the workflow document when a stall occurs mid-session.

**Impact:** V12 experienced 3 developer stalls. The PO eventually switched to the `general` agent type — an effective workaround, but one discovered through trial-and-error rather than plan guidance.

**Fix:** Add a "Troubleshooting" section: "If the developer agent produces empty output or stalls, re-delegate the incomplete work to a fresh session. If stalling persists (2+ consecutive failures), switch to the `general` agent type. Limit each delegation to at most 2 tasks to reduce stall probability."

### 2.5 Task 6 Entry Point Coverage Gap (-1 point)

**Problem:** Task 6 specifies `bin/run.php` behavior (error handling, exit codes, no-args behavior) but provides no testable acceptance criteria for these behaviors. The only test specified is a unit test for `PokemonFormatter`.

The `bin/run.php` file is excluded from `src/` coverage, but its logic (error handling, exit codes) is non-trivial. The Smoke Test in Task 7 partially covers the happy path but doesn't verify exit codes or per-pokemon error handling.

**Impact:** Entry point error-handling logic is implicitly tested via the Smoke Test, but exit codes and stderr output are not verified. This hasn't caused a grade deduction in practice because the quality report accepts `file_get_contents` as a product decision, but it's a gap in the plan's completeness.

**Fix:** Add to Task 7 AC: "Smoke test verifies: (1) happy path output, (2) error path outputs to stderr and returns non-zero exit code" or explicitly state "bin/run.php exit code behavior is not tested — accepted as product decision."

### 2.6 `file_get_contents` Not Addressed (-0.5 points)

**Problem:** Line 22 states "`file_get_contents` is acceptable for this kata" without providing guidance on how to use it correctly. Tasks 4 and 6 don't specify whether to use `@file_get_contents`, explicit error checking, or stream context.

**Impact:** V10 uses bare `file_get_contents`, V11 uses `file_get_contents(...) ?: throw`, V12 uses `@file_get_contents(...) === false`. All work but each is different. The plan's silence on this detail means the implementation varies by LLM interpretation.

**Fix:** Add to Task 4 or 6 AC: "The HTTP fetching closure in `bin/run.php` uses `file_get_contents($url)` with explicit `=== false` check and throws `PokeApiException` on failure." or acknowledge it as an implementation detail left to the developer.

### 2.7 Critic W1 Not Resolved in Backlog (-0.5 points)

**Problem:** The Critic identified W1 (IMPORTANT): "`GrowthRateLevel` pairs a `Level` with a 'minimum experience threshold (non-negative int)' — the field name for the threshold is never explicitly named in the VO spec."

Looking at the backlog (line 221), it was actually already resolved: "fields `Level $level` and `int $minimumExperience`". The Critic appears to have missed this during its review, or the backlog was updated after the Critic review without re-validation.

**Impact:** Minor — the field name IS present in the final backlog. But the fact that the Critic flagged something that's already addressed indicates the review loop wasn't fully closed (the PO didn't produce a written response to the Critic's findings documenting which were addressed vs. not).

**Fix:** After Critic review, the PO should add a "Critic Response" section or append to the Critic file: "W1: Already addressed — see backlog line 221. No change needed."

---

## 3. Things to Improve

### Priority 1: Make implicit rules explicit in every task

| Rule | Currently | Should be |
|------|-----------|-----------|
| No FQN (use imports) | Only in Task 7 | Global constraint + each task AC |
| Test classes `final` | Not mentioned | Task 7 AC or global constraint |
| Review per task | Assumed from IMPLEMENTATION.md | Explicit in plan's Process section |

### Priority 2: Add a "Global Constraints" section

Currently, constraints are spread across "Constraints" (line 57), "Architecture Guidelines" (line 67), "Lessons" (line 351), and individual task ACs. A lower-reasoning LLM may miss rules that aren't in the task it's currently implementing.

**Proposed addition (after "Constraints" section):**

```markdown
## Global Code Quality Rules (apply to ALL tasks)

- All classes (source AND test) must be `final` unless explicitly designed for extension
- All files must use `use` imports — no fully-qualified names with leading backslash
- No `assert()` — use explicit `if` + `throw` guards
- All test names follow `it_*` pattern describing the scenario
- Named fakes only — no anonymous classes, no mocks
- `json_encode()` in tests requires `JSON_THROW_ON_ERROR` for PHPStan
```

### Priority 3: Add stall-recovery guidance

A section titled "Troubleshooting" or "Known Issues" that addresses:
- Developer stalls: how to diagnose, re-delegate, or switch agent type
- Maximum delegation batch size (already in IMPLEMENTATION.md but should be repeated)
- What to do when a test framework change breaks something

### Priority 4: Close the Critic loop

After the Critic review, add a documented response that maps each finding to either:
- "Addressed: see backlog line X"
- "Not addressed: [justification]"
- "Accepted as-is: [reason]"

This ensures no finding is lost or misattributed.

---

## 4. Instructions to Change

### In `.ai/team/workflows/PLANNING.md`

Add after the existing bullet points (line 18):

```markdown
- The backlog must include a "Global Code Quality Rules" section listing all rules that apply to every task (FQN imports, final classes, no assert, test naming). These rules must not be buried in individual task ACs where they can be missed.
- After the Critic review (step 5), the PO must produce a written response mapping each finding to "Addressed (line X)" or "Not addressed (justification)". This response is appended to the Critic file or saved as a separate file.
```

### In `.ai/team/workflows/IMPLEMENTATION.md`

Strengthen step 6.3:

```markdown
6.3. When the Developer is finished, PO MUST ask the Reviewer (@reviewer) for a review.
     This step is mandatory for every task. The PO must not skip reviews even if prior 
     reviews passed cleanly. If the Reviewer finds no issues, the review still serves as 
     confirmation that coding standards (FQN, final, naming) are maintained.
```

Add to "How to handle unexpected situations":

```markdown
- If developer sessions stall more than once consecutively on the same delegation:
  1. Reduce the delegation scope to a single task
  2. Include concrete code examples (existing class signatures, constructor parameters)
  3. If stalling persists after 2 re-delegations, switch to the `general` agent type
  4. Document the switch in MEMORY.md for future iterations
```

### In the backlog template (for future iterations)

Add a section between "Constraints" and "Architecture Guidelines":

```markdown
## Global Code Quality Rules

These rules apply to ALL code written in ALL tasks. They are repeated here because
lower-reasoning LLMs may not reference external documents during implementation.

- All classes (source AND test) must be `final` unless designed for extension
- All files must use `use` imports — no fully-qualified names with leading backslash
- No `assert()` — use explicit `if (!...) { throw ... }` guards
- Test names: `it_<scenario_description>()`
- Named fakes in `tests/Support/` — no anonymous classes, no mocks
- `json_encode()` in tests needs `JSON_THROW_ON_ERROR` for PHPStan
- `json_decode()` with `JSON_THROW_ON_ERROR`, then type-check every field

## Process Requirements

- Each task MUST be reviewed by @reviewer before commit
- Maximum 2–3 tasks per developer delegation
- If developer stalls: re-delegate with concrete signatures; after 2 failures, switch agent type
```

---

## 5. Grade

| Dimension | Weight | Score | Notes |
|-----------|--------|-------|-------|
| Specificity & completeness | 25% | 95/100 | Excellent — nearly every class, field, and behavior specified |
| PLANNING.md compliance | 15% | 100/100 | All rules satisfied with evidence |
| Architecture correctness | 15% | 100/100 | Confirmed by Architect review; matches ARCHITECTURE.md |
| Clarity for lower-reasoning LLM | 20% | 85/100 | Good but some rules are scattered/implicit |
| Process guidance | 10% | 70/100 | Missing reviewer mandate, stall recovery, Critic response loop |
| Defensive completeness | 10% | 80/100 | FQN rule buried, test `final` missing, entry point gaps |
| Proven effectiveness | 5% | 98/100 | Produced 98.85–99.75/100 across 3 LLM runs |

**Weighted total: 90.85 → rounded to 91/100**

---

## 6. Grade Justification

The plan scores 91/100 because it is **highly effective** (proven by 3 implementations scoring 98.85–99.75) but has **gaps in explicitness** that caused predictable failures in lower-reasoning LLMs:

**Why not higher:**
- The FQN import rule is mentioned once in Task 7 but not reinforced globally (-3). V12 lost 0.5 points directly from this gap.
- No explicit `final` requirement for test classes (-2). V12 lost 0.1 points from this.
- No reviewer frequency mandate (-2). V12 lost 0.25 points from skipped reviews.
- No stall-recovery guidance (-1.5). V12 lost time to 3 stalls.
- Entry point testing gap (-1). Not graded but represents incomplete specification.

**Why not lower:**
- The plan's core architecture is flawless — no implementation deviated from the directory tree or namespace mapping.
- Acceptance criteria are precise enough that all 3 implementations achieved 100% test coverage and PHPStan max level.
- The Lessons section prevents the most common V1–V9 failure modes.
- The bug analysis prevents incorrect behavior interpretation.
- The data flow diagram eliminates wiring confusion.

**Grade: 91 / 100**
