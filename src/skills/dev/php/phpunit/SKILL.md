---
name: telamon.phpunit
description: "PHPUnit conventions: test attributes, avoiding risky/slow warnings, handler cleanup, slow test detector, e2e testing pattern for framework-agnostic libraries. Use when writing or reviewing PHP tests with PHPUnit."
---

# PHPUnit

## When to Apply

- Writing new PHPUnit test classes or methods
- Reviewing PHP test files for correctness and hygiene
- Debugging risky, slow, or warning-flagged tests
- Writing e2e tests for libraries designed to work across frameworks

## Test Philosophy

- The PHPUnit output must report zero warnings, zero notices, and zero risky tests. Every section below explains how to prevent a specific issue type.
- Every test must have a reason to exist — "What bug would this catch?"
- Tests should be obvious, not clever.
- Test behavior, not implementation.
- Never write tests that only verify class structure through reflection. Tests must exercise code paths and assert observable behavior.

## Test Attributes

Use PHPUnit attributes (not annotations) for all test metadata:

```php
use PHPUnit\Framework\Attributes\Test;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\Large;

#[Test]
public function it_dispatches_the_command(): void { }
```

Do not use `@test`, `@dataProvider`, or `@group` annotations — they are deprecated in PHPUnit 12+.

## Preventing Risky Test Warnings

PHPUnit flags a test as **risky** when it detects side effects that were not cleaned up.

### Error and exception handlers

**Problem**: frameworks like Laravel register custom error/exception handlers via `set_error_handler()` and `set_exception_handler()` during bootstrap. PHPUnit detects these were pushed onto the handler stack but never removed, producing:

> *Test code or tested code did not remove its own error handlers*  
> *Test code or tested code did not remove its own exception handlers*

**Solution**: snapshot the handler stack depth before booting the framework, then pop exactly the handlers that were added.

```php
private int $errorHandlerDepthBeforeBoot = 0;
private int $exceptionHandlerDepthBeforeBoot = 0;

protected function setUp(): void
{
    parent::setUp();

    $this->errorHandlerDepthBeforeBoot = $this->snapshotErrorHandlerDepth();
    $this->exceptionHandlerDepthBeforeBoot = $this->snapshotExceptionHandlerDepth();

    // ... boot the framework / application ...
}

protected function tearDown(): void
{
    // ... tear down the framework / application ...

    $added = $this->snapshotErrorHandlerDepth() - $this->errorHandlerDepthBeforeBoot;
    for ($i = 0; $i < $added; $i++) {
        restore_error_handler();
    }

    $addedEx = $this->snapshotExceptionHandlerDepth() - $this->exceptionHandlerDepthBeforeBoot;
    for ($i = 0; $i < $addedEx; $i++) {
        restore_exception_handler();
    }

    parent::tearDown();
}
```

The snapshot helpers drain the stack non-destructively (collect all handlers, then re-install them in reverse order) to count the current depth.

**Why not `set_error_handler($previousHandler)`?** Because `set_error_handler()` *pushes* a new entry — it does not replace. Calling `set_error_handler(PHPUnit's handler)` makes the stack one level deeper, not the same. Always use `restore_error_handler()` / `restore_exception_handler()` to pop.

### Other common risky-test causes

- **Output during test**: use `$this->expectOutputString()` or `ob_start()`/`ob_end_clean()`
- **Global state mutation**: reset statics and singletons in `tearDown()`
- **No assertions**: every test method must contain at least one assertion

## Preventing Slow Test Warnings

This project uses `ergebnis/phpunit-slow-test-detector`. The global threshold is 0.500 seconds.

### `#[MaximumDuration]` attribute

For tests that take longer (real broker I/O, `sleep()` for TTL expiry, etc.), add a per-method threshold:

```php
use Ergebnis\PHPUnit\SlowTestDetector\Attribute\MaximumDuration;

#[MaximumDuration(5_000)]
#[Test]
public function it_consumes_from_the_queue(): void { }
```

**`MaximumDuration` targets methods only** (`#[\Attribute(\Attribute::TARGET_METHOD)]`). It cannot be applied at the class level — PHP silently ignores misapplied attributes and the detector will not read it.

### Budget guidelines

| Test type | Budget |
|---|---|
| Unit test (no I/O) | Global default (0.500s) — no attribute needed |
| Integration test with real DB | Global default, or `#[MaximumDuration(1_000)]` if timing is tight |
| Test with `sleep()` for TTL/timeout | Sleep duration + 1s margin (e.g., `sleep(2)` → `#[MaximumDuration(3_000)]`) |
| E2e test with real brokers (Redis, Kafka) | `#[MaximumDuration(5_000)]` |
| E2e test consuming from Kafka | `#[MaximumDuration(10_000)]` — Kafka consumer timeout adds latency |
| Kafka connector integration test | `#[MaximumDuration(20_000)]` — full broker round-trip |

### When to add the attribute

Add `#[MaximumDuration]` when writing the test, not after the slow warning appears. If a test interacts with a real broker, network service, or uses `sleep()`, it will be slow — tag it proactively.

## Preventing PHPUnit Notices (Mock vs Stub)

PHPUnit 12+ emits a notice when a mock object has no expectations configured:

> *No expectations were configured for the mock object*

**Fix**: if you only need a stand-in object that returns values, use `createStub()` instead of `createMock()`:

```php
// BAD — triggers notice in PHPUnit 12+
$logger = $this->createMock(LoggerInterface::class);
$logger->method('info')->willReturn(null);

// GOOD — stubs don't expect calls
$logger = $this->createStub(LoggerInterface::class);
$logger->method('info')->willReturn(null);
```

Use `createMock()` only when you actually call `->expects()`.

## E2E Testing for Framework-Agnostic Libraries

When a library is designed to work across multiple frameworks (e.g., Laravel and Symfony), e2e tests must exercise the full stack without coupling to any one framework.

### Architecture: Application Factory pattern

1. **Define a framework-agnostic interface** (`EndToEndApplicationFactory`) in `tests/e2e/` with methods for all test operations: dispatching, consuming, asserting queue state, managing locks, rate limiters, circuit breakers, etc.

2. **Implement per framework** in `tests/e2e/<Framework>/` (e.g., `tests/e2e/Laravel/LaravelEndToEndApplicationFactory`). Only the factory implementation imports framework classes.

3. **Write tests against the interface** in `tests/e2e/TestCase/`. Test files import nothing from any framework — only from `tests/e2e/` and the library's own ports.

4. **Resolve the factory at runtime** via an environment variable (e.g., `E2E_APPLICATION_FACTORY`), defaulting to one framework.

```
tests/e2e/
├── EndToEndApplicationFactory.php    # Interface
├── EndToEndTestCase.php              # Base test case (framework-agnostic)
├── Laravel/
│   ├── LaravelEndToEndApplicationFactory.php
│   └── Resolver/                     # E2e-specific config resolvers
├── Symfony/
│   └── SymfonyEndToEndApplicationFactory.php
├── TestCase/                         # All test files (framework-agnostic)
│   ├── CommandDispatcherE2eTest.php
│   └── ...
└── TestMessage/                      # Fixtures (commands, events, handlers)
```

### Key rules

- **Zero framework imports in test files** — only the factory interface and the library's own ports
- **Separate e2e resolvers from unit test resolvers** — unit tests typically use a database broker for queue inspection (`DB::select('select * from jobs')`); e2e tests use real brokers (Redis, Kafka). Sharing resolvers between them causes cross-contamination
- **Handler cleanup in the base test case** — see "Preventing Risky Test Warnings" above
- **Architecture rule exclusion** — if the project enforces "every test class must have a corresponding production unit", exclude `tests/e2e/` from that rule since e2e tests by design have no 1:1 production counterpart

### Factory lifecycle

```
setUp()     → boot() → reset() → [run test]
tearDown()  → tearDown() → [restore handlers] → parent::tearDown()
```

- `boot()`: create the application, configure brokers
- `reset()`: flush queues, truncate tables, drain topics — called before each test for isolation
- `tearDown()`: clean up application resources

### Broker-specific considerations

| Broker | Queue inspection | Consumption | Notes |
|---|---|---|---|
| Database | `DB::select()` on `jobs` table | `Queue::pop()` | Full introspection available |
| Redis | `LRANGE` for pending, `ZCARD`/`ZRANGE` for delayed | `Queue::pop()` | Payloads are JSON with `attempts` field |
| Kafka | No peek capability | `KafkaQueue::pop()` with consumer timeout | Use consume + side-effect assertions instead of queue inspection |

## See also

- `telamon.testing` skill — project-wide test strategy, commands, conventions
- `telamon.message_bus` skill — message bus handler testing patterns
- `telamon.php_rules` skill — PHP coding conventions
