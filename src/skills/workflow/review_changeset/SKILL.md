---
name: telamon.review_changeset
description: "Reviews a code changeset against a plan and project conventions. Use when reviewing code changes from a developer, after implementation is complete and ready for review."
---

# Skill: Changeset Review

Systematic code review of a changeset against an architect's plan and project conventions.

## When to Apply

- After a developer signals task completion and readiness for review
- When reviewing a PR or code changeset before merge

## Review Workflow

Execute these steps in order before writing any review report.

### 0. Run the Test Suite

Run the test command. Record pass/fail, number of tests, failures. Failing tests are an automatic BLOCKER. Complete remaining steps regardless.

### 1. Parameter & Argument Integrity

For every added or modified method:
- Verify every parameter is used in the method body. Flag parameters silently ignored in favour of hardcoded values.
- Verify call-site arguments match the parameter's semantic intent, not just its type.

### 2. Dead Code & Orphaned References

When a class, method, or interface is deleted or renamed:
- Search the entire codebase for remaining references (DI bindings, config, architectural rules, baselines, routes, docs).
- Check for orphaned imports and dead container bindings.

### 3. Dependency Wiring Completeness

When constructor or factory signatures change:
- Verify all container bindings, registrations, and factories supply the new parameters.
- Verify variadic/collection parameters are wired, not silently defaulting to empty.
- Verify new bindings are registered in the component's own ServiceProvider, not in the root AppServiceProvider (unless the binding is cross-cutting). Component encapsulation requires each bounded context to own its wiring.

### 4. Import Hygiene

After any file modification:
- No unused imports remaining.
- No missing imports for newly referenced symbols.

### 5. Cross-file Rename Consistency

When any symbol is renamed:
- Search all file types (source, config, YAML, JSON, TOML, Markdown, architectural rules, baselines).
- Verify references in comments, doc tags, and string-based references are updated.

### 6. Test Assertion Completeness

For every added or modified test method:
- Verify every assertion matches what the method name claims.
- Flag any test whose name states an ordering, cardinality, or conditional but whose body only asserts existence or non-null.
- Example violation: name says "after" or "before" but body never compares positions.

**Test coverage regression check** — When an existing test is modified, compare the set of assertions before and after:
- If assertions were removed or narrowed (e.g. full-row content comparison reduced to header-only), flag it as a WARNING unless the test's name was also updated to reflect the reduced scope.
- A test named `amounts_are_converted_using_billing_rate` that no longer asserts anything about amounts or conversion is a BLOCKER — the test name makes a promise the body must keep.
- Fixture files (`*.csv`, `*.json`, `*.xml`, snapshot files) that are updated in the changeset but are no longer loaded by any test are dead fixtures — flag as WARNING and require deletion or re-use.
- Verify test classes don't import traits already provided by the base TestCase (e.g. `RefreshDatabase` when base uses `LazilyRefreshDatabase`). Redundant traits can cause subtle behavior changes.

**Extension dependency guards** — When a test uses functions from optional PHP extensions (`pcntl_*`, `posix_*`, `rdkafka_*`, `imagick_*`, etc.):
- Verify that `extension_loaded()` checks cover **all** required extensions, not just the primary one. A test using both `pcntl_signal()` and `posix_kill()` must guard both `pcntl` and `posix` — flag a missing guard as WARNING.
- Check for functions from secondary extensions that are easy to miss (e.g. `posix_kill`/`posix_getpid` alongside `pcntl_signal`).

**Global state restoration** — When a test modifies global PHP process state (`pcntl_async_signals()`, `pcntl_signal()`, `ini_set()`, `putenv()`, `date_default_timezone_set()`, `error_reporting()`, or similar):
- Verify the test captures the previous value before modifying it and restores it in a `finally` block.
- A bare restore at the end of the method body (not wrapped in `finally`) is a WARNING — if the test fails or throws, the restore is skipped and subsequent tests run with polluted global state.

**tearDown lifecycle safety** — When a `tearDown()` or `tearDownAfterClass()` method performs multiple cleanup steps (e.g. calls an external teardown, restores handler stacks, calls `parent::tearDown()`):
- Verify the steps are wrapped in nested `try/finally` blocks so every cleanup step runs even if an earlier one throws.
- `parent::tearDown()` must be in the innermost `finally` to guarantee PHPUnit's own cleanup always executes.
- A `tearDown()` that calls an external method (framework factory, application kernel, etc.) before other cleanup without `try/finally` is a WARNING — if the external call throws, remaining cleanup is skipped and corrupted state cascades into subsequent tests.

### 7. Static Analysis Baseline Hygiene

When `phparkitect.baseline.json`, `phpstan-baseline.neon`, or any other static-analysis baseline file is modified:
- Any new entry added is a BLOCKER — the architecture rule states baselines must not grow (see ARCHITECTURE.md "Do not add issues to static analysis tools baselines").
- Accept only removals. Require the developer to fix the violation or update the architectural rule instead.

### 8. Decorator & Wrapper Integrity

When a decorator or wrapper class forwards calls to an inner dependency:
- Every parameter of the decorated method must be forwarded — flag any that are silently dropped.
- When an inner method's signature has de-facto convention parameters not declared in the interface (e.g. `$index` on `Queue::pop()`), verify the decorator forwards them so the inner object's behaviour is not silently broken.

### 9. State-Machine Reset Placement

When a method maintains mutable state that accumulates across calls and resets on a condition:
- Verify the reset fires on the correct branch. Resetting on the job-found path (early return) when the intent is to reset only on completion (null/empty path) is a BLOCKER — it discards state that was intentionally accumulated.
- Verify that every caller path that should seed the accumulator does so before it is consumed. A conditional seed (`if empty → seed`) that leaves the accumulator stale when it is non-empty is a BLOCKER.

### 10. Utility Method Abstraction Bypass

When a method calls a sibling method to reuse logic, verify the sibling's internal invariants hold for every call sequence the caller produces.
- If the sibling has its own state machine, check that the caller does not drive it into an inconsistent state (e.g. pre-registering side-channel entries that are then consumed out of order).
- Prefer direct computation over indirect state manipulation when the sibling's state machine was not designed for external driving.

### 11. N+1 Query Regression

When a changeset introduces a bulk-load (e.g. `whereIn`, `with()`, eager loading) to avoid per-row queries:
- Search the entire flow for any remaining call that lazily loads the same relation on individual models (e.g. `$model->relation` inside a loop, or a called method that accesses `$model->relation` internally).
- A bulk-load that coexists with a per-row lazy load of the same relation in the same pipeline is a WARNING — the optimization is incomplete and N+1 queries still occur.
- Check called methods (not just inline code) — a helper like `fromBillingTrip()` may load `$billingTrip->trip` even if the handler pre-fetches trips separately.

### 12. `@phpstan-ignore` and Type-Masking

When a `@phpstan-ignore` or `@phpstan-ignore-next-line` comment is added or already present on modified code:
- Identify what error is being suppressed and whether it indicates a genuine type mismatch rather than a PHPStan false positive.
- Under `strict_types=1`, passing a `string` where `int` is declared raises a `TypeError` at runtime. Eloquent commonly returns numeric strings for integer columns when the attribute lacks a cast. A callback typed as `fn (int $id)` applied to a plucked integer column is unsafe without a cast — flag as WARNING and suggest `fn (string|int $id): T => new T((int) $id)`.
- An `@phpstan-ignore` that hides a real type mismatch rather than a PHPStan false positive is a WARNING, not an acceptable suppression.

### 13. Primitive Obsession in Commands & Boundaries

When a command, query, or controller is added or modified:
- Verify constructor parameters use Value Objects when one exists in the domain (e.g. `UserId` not `int`, `HotelId` not `int`, `Mailbox[]` not `string[]`).
- Verify controller `authorize()` calls pass VOs to policies, not raw primitives, when the VO is already constructed in the controller.
- Verify policy methods accept the corresponding VO type, not the primitive.
- A command accepting a raw primitive when a domain VO exists for that concept is a WARNING.

### 14. Hardcoded Configuration Values

When application or domain layer handlers are added or modified:
- Flag hardcoded URLs, hostnames, ports, API keys, or environment-dependent strings. These should be injected via constructor + config binding (`giveConfig` or similar).
- Hardcoded values that vary per environment (dev/staging/prod) are a WARNING — they break deployment flexibility and testability.
- Pure domain constants (e.g. mathematical formulas, enum values) are not configuration and should remain inline or as class constants.

### 15. Magic Values — Use Class Constants

When a handler, service, or domain class uses literal numbers or strings with domain meaning:
- Flag inline magic numbers (e.g. TTL durations, retry counts, thresholds) and magic strings (e.g. email subjects, status labels) that should be class constants.
- Class constants make intent explicit, enable reuse, and simplify testing.
- A magic value used in more than one place is a WARNING. A single-use magic value with non-obvious meaning is an INFO.

### 16. Kubernetes Manifest Consistency

When a changeset includes Kubernetes YAML manifests (any file with `apiVersion` and `kind`):
- When multiple resources share the same `apiVersion`/`kind`, verify they have consistent ArgoCD annotations (`sync-wave`, `sync-options`). Inconsistent annotations across resources of the same kind is a WARNING.
- When a resource uses a Custom Resource `apiVersion` (not core `v1`, `apps/v1`, `batch/v1`, `networking.k8s.io/v1`, etc.), verify it has `argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true` if the CRD is installed by another Application in the same changeset. Missing this annotation causes ArgoCD dry-run failures on first sync — flag as WARNING.
- When a `kustomization.yaml` exists in the same directory as a new resource file, verify the new file is listed in `resources:`. An unlisted resource in a Kustomize-managed directory will not be synced — flag as BLOCKER.

### 17. PSR-3 Exception Logging

When a `catch` block logs via a PSR-3 logger method (`->warning()`, `->error()`, `->critical()`, `->alert()`, `->emergency()`):
- Verify the context array includes `'exception' => $catchVariable`. The PSR-3 spec reserves the `'exception'` key so log handlers can extract the full stack trace — without it, only the message string is captured.
- Missing the exception object in a `->warning()` or `->error()` call inside a catch block is a WARNING.
- A catch block that logs `$e->getMessage()` but omits `'exception' => $e` is the most common pattern to flag.

### 18. PHP Error Suppression Operator

When the `@` operator is used on any function or method call:
- Flag as WARNING — the `@` operator suppresses all PHP errors indiscriminately, hiding potentially important warnings and making debugging difficult.
- Require a targeted `set_error_handler`/`restore_error_handler` pair in a `try/finally` block instead, so only expected warnings are suppressed and unexpected ones remain observable.
- The only acceptable use of `@` is on trivially safe operations where failure is immediately checked (e.g. `@unlink()` followed by an existence check).

### 19. Log Level Appropriateness

When a log statement is added or modified in a method that is called repeatedly (worker loops, per-request handlers, queue consumers, scheduled tasks):
- Verify the log level is appropriate for the call frequency. `info` or higher in a hot path that fires every iteration generates high-volume logs and cost.
- Routine "nothing happened" messages (e.g. partition empty, no work found, heartbeat) should be `debug` level — flag `info`+ as WARNING.
- Actionable events (message received, error encountered, retry triggered) are appropriate at `info` or higher.

## Review Report

Save to `<issue-folder>/REVIEW-YYYY-MM-DD-NNN.md`.

### Template

> # Review Report
>
> **Verdict**: APPROVED | CHANGES REQUESTED | ESCALATED
>
> - **Test Suite** — Pass/fail, test count, failures.
> - **Plan Compliance** — Does implementation match the plan? All steps complete? Unauthorized deviations?
> - **Directory Structure** — File layout matches architecture document?
> - **Domain Quality** — Rich models (not anemic)? Value Objects for domain concepts? Classes sealed/final?
> - **Port Contracts** — Typed DTOs? No raw arrays crossing boundaries? Cross-layer exceptions at port level? No transport leaks?
> - **Application Boundary** — DTOs returned (not domain entities) to presentation?
> - **Parameter & Argument Integrity** — Parameters used? Arguments semantically correct?
> - **Dead Code & Orphaned References** — Old references removed across entire codebase?
> - **Dependency Wiring** — Registrations updated for new parameters? Variadic params wired?
> - **Import Hygiene** — No unused or missing imports?
> - **Cross-file Rename Consistency** — All references updated across all file types?
> - **Test Quality** — Descriptive names? Comprehensive coverage? Reusable named test doubles? Assertions match method name claims (ordering, cardinality, conditions)? No coverage regression (assertions not removed or narrowed without updating the test name)? No orphaned fixture files? Extension guards cover all required extensions (not just the primary)? Global state modifications restored in `finally` blocks? tearDown() methods with multiple cleanup steps wrapped in nested try/finally?
> - **Static Analysis Baseline Hygiene** — No new entries added to any baseline file?
> - **Decorator & Wrapper Integrity** — All parameters forwarded through decorators? De-facto convention params forwarded?
> - **State-Machine Reset Placement** — Resets on the correct branch? Every path that should seed the accumulator does so?
> - **Utility Method Abstraction Bypass** — Sibling method state machine not driven into inconsistent state?
> - **N+1 Query Regression** — Bulk-loads not undermined by remaining per-row lazy loads in the same pipeline (including in called helper methods)?
> - **`@phpstan-ignore` and Type-Masking** — Suppressions masking real type mismatches (e.g. `string` vs `int` under `strict_types=1`) rather than PHPStan false positives?
> - **Primitive Obsession** — Commands, queries, and controller authorize calls use VOs when domain VO exists? Policies accept VOs not primitives?
> - **Hardcoded Configuration** — No hardcoded URLs, hostnames, or environment-dependent values in application/domain handlers?
> - **Magic Values** — Domain-meaningful literals extracted to class constants?
> - **Kubernetes Manifest Consistency** — Same-kind resources have consistent ArgoCD annotations? Custom CRD resources have `SkipDryRunOnMissingResource`? New files listed in `kustomization.yaml`?
> - **PSR-3 Exception Logging** — Catch blocks that log include `'exception' => $e` in context for stack traces?
> - **PHP Error Suppression** — No `@` operator usage? Targeted error handlers used instead?
> - **Log Level Appropriateness** — Hot-path log statements use `debug` for routine "nothing happened" messages?
> - **Code Style** — Symbols imported? No FQCNs inline? Explicit guards? Sealed/final convention?
> - **Role Compliance** — All code changes made by the Developer?
> - **Documentation** — Manual config steps documented? Obsolete steps removed?
>
> ## Findings
>
> _If none: "No findings. All checks passed."_
>
> ### Finding <n>: <Title>
> - **Severity**: BLOCKER | WARNING | INFO
> - **File path**:
> - **Problem found**:
> - **Why it matters**:
> - **Correct approach**:
>
> ## Tools used
>
> ### SKILLS
> List skills used by the agent while doing the review, or "None."
>
> ### MCP tools
> List MCP tools used by the agent while doing the review, or "None."

### Severity Definitions

- **BLOCKER** — Must fix before merge. Breaks functionality, fails tests, or violates a hard architectural rule.
- **WARNING** — Should fix. Violates conventions or likely to cause issues. When in doubt vs BLOCKER, choose BLOCKER.
- **INFO** — Consider fixing. Style or readability improvement with no functional impact.

### Handling No Findings

When verdict is APPROVED, still produce the full report with every section addressed. Mark each section with "No issues found." This confirms the check was performed.
