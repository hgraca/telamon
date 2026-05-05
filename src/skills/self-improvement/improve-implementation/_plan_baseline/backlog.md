# Backlog — Kata: PokeAPI Parser Refactoring (v10)

## Goal

Refactor a procedural PHP script (`bin/run.php`) that fetches Pokemon data from the PokeAPI into a clean, well-tested codebase following Explicit Architecture (DDD + Hexagonal + CQRS). The solution must use the `get-e/message-bus` Dummy adapter to dispatch query objects synchronously. This iteration targets **100/100** on the quality report by closing all remaining gaps from v9.

## Problem Analysis

The current `bin/run.php`:
1. Makes 6 HTTP calls per pokemon (4 to the pokemon endpoint — 3 are unnecessary duplicates — plus 1 species and 1 growth rate). The refactored version reduces this to 3 calls (1 pokemon + 1 species + 1 growth rate)
2. Has all logic in a single procedural script — no separation of concerns
3. Contains a **level calculation bug**: `$pokeLevel` is only assigned inside the `break` block (line 28–29); when experience exceeds all growth rate thresholds, the `if` condition is never true, so `break` never fires, the loop completes normally, and `$pokeLevel` retains its initial value of `0` instead of being set to `$possibleLevel` (which holds the max level). **Note**: The README example inputs (ivysaur 142, bulbasaur 64, pikachu 112, ditto 101) do NOT trigger this bug — their experience values all fall between thresholds. The bug only manifests for pokemon with experience exceeding all thresholds. Byte-identical output for the README example is expected despite the fix.
4. Has no tests, no domain model, no architecture

## Gaps from Prior Iteration (v9) to Close

| Gap | Points lost | Fix |
|-----|-------------|-----|
| Test coverage 95.38% not 100% | -1.5 | Target every uncovered branch with dedicated tests |
| No `rawurlencode()` on pokemon name in URL | -0.5 | Add `rawurlencode($name->value)` in `HttpPokemonDataProvider` |
| Composer name not customized | -0.25 | Rename to `gete/poke-parser` |
| `bin/run.php` resource management | -0.25 | Minor; `file_get_contents` is acceptable for this kata |

## Data Flow

```
bin/run.php (CLI entry point)
  |
  v
Message Bus (Dummy adapter, sync dispatch)
  |
  v
Query Handler: GetPokemonLevel
  |
  +---> PokemonDataProvider port ---> HttpPokemonDataProvider
  |       (2 HTTP calls: GET /pokemon/{name} + GET {species_url})
  |       returns PokemonDataResult (name, experience, species name, growth rate reference)
  |
  +---> GrowthRateLevelProvider port ---> HttpGrowthRateLevelProvider
  |       (1 HTTP call: GET {growth_rate_url})
  |       returns GrowthRateLevelTable (sorted level/experience pairs)
  |
  +---> GrowthRateLevelTable.levelFor(experience) ---> Level
  |
  +---> Construct Pokemon domain VO (name, experience, species, level)
  |
  v
PokemonLevelResult DTO (application layer, primitives only)
  |
  v
PokemonFormatter (formats output string)
  |
  v
stdout (no trailing newline, matching original behavior)
```

## Constraints

- All commands must run inside the project's Docker container: `docker run --rm -w /app -v "$PWD":/app php:8.4-cli bash`
- PHP ^8.4 (as per `composer.json`)
- Must use `get-e/message-bus:dev-feature/dummy-adapter` with private VCS repository
- Static analysis: PHPStan at max level, 0 errors
- Test coverage: **100%** of `src/` (aim for 100%; 90% is the floor, not the goal)
- The refactored code must produce correct output matching the README example
- This is a standalone PHP kata — no Laravel, no framework service container

## Architecture Guidelines

### Directory Structure

```
src/
├── Core/
│   ├── Component/
│   │   └── Pokemon/
│   │       ├── Domain/
│   │       │   ├── PokemonName.php
│   │       │   ├── BaseExperience.php
│   │       │   ├── SpeciesName.php
│   │       │   ├── Level.php
│   │       │   ├── GrowthRateLevel.php
│   │       │   ├── GrowthRateLevelTable.php
│   │       │   └── Pokemon.php
│   │       └── Application/
│   │           └── Query/
│   │               └── GetPokemonLevel/
│   │                   ├── GetPokemonLevel.php
│   │                   ├── GetPokemonLevelHandler.php
│   │                   └── PokemonLevelResult.php
│   └── Port/
│       └── PokeApi/
│           ├── PokemonDataProvider.php
│           ├── GrowthRateLevelProvider.php
│           ├── PokemonDataResult.php
│           ├── GrowthRateReference.php
│           └── PokeApiException.php
├── Infrastructure/
│   ├── MessageBus/
│   │   └── MapHandlerResolver.php
│   └── PokeApi/
│       └── Http/
│           ├── HttpPokemonDataProvider.php
│           └── HttpGrowthRateLevelProvider.php
└── Presentation/
    └── Cli/
        └── PokemonFormatter.php

bin/
└── run.php

tests/
├── Support/
│   ├── InMemoryPokemonDataProvider.php
│   ├── InMemoryGrowthRateLevelProvider.php
│   └── FakeHttpClient.php
├── Unit/
│   ├── Core/
│   │   ├── Component/
│   │   │   └── Pokemon/
│   │   │       └── Domain/
│   │   │           ├── PokemonNameTest.php
│   │   │           ├── BaseExperienceTest.php
│   │   │           ├── SpeciesNameTest.php
│   │   │           ├── LevelTest.php
│   │   │           ├── GrowthRateLevelTest.php
│   │   │           ├── GrowthRateLevelTableTest.php
│   │   │           └── PokemonTest.php
│   │   └── Port/
│   │       └── PokeApi/
│   │           ├── GrowthRateReferenceTest.php
│   │           └── PokemonDataResultTest.php
│   ├── Infrastructure/
│   │   └── MessageBus/
│   │       └── MapHandlerResolverTest.php
│   └── Presentation/
│       └── Cli/
│           └── PokemonFormatterTest.php
└── Integration/
    ├── Core/
    │   └── Component/
    │       └── Pokemon/
    │           └── Application/
    │               └── Query/
    │                   └── GetPokemonLevel/
    │                       └── GetPokemonLevelHandlerTest.php
    ├── Infrastructure/
    │   └── PokeApi/
    │       └── Http/
    │           ├── HttpPokemonDataProviderTest.php
    │           └── HttpGrowthRateLevelProviderTest.php
    └── SmokeTest.php
```

### Namespace Mapping

| Directory | Namespace |
|-----------|-----------|
| `src/Core/Component/Pokemon/Domain/` | `Gete\PokeParser\Core\Component\Pokemon\Domain` |
| `src/Core/Component/Pokemon/Application/Query/GetPokemonLevel/` | `Gete\PokeParser\Core\Component\Pokemon\Application\Query\GetPokemonLevel` |
| `src/Core/Port/PokeApi/` | `Gete\PokeParser\Core\Port\PokeApi` |
| `src/Infrastructure/MessageBus/` | `Gete\PokeParser\Infrastructure\MessageBus` |
| `src/Infrastructure/PokeApi/Http/` | `Gete\PokeParser\Infrastructure\PokeApi\Http` |
| `src/Presentation/Cli/` | `Gete\PokeParser\Presentation\Cli` |
| `tests/Support/` | `Gete\PokeParser\Test\Support` |

### Key Design Decisions

- **GrowthRateReference** has a `value(): string` method. The opacity constraint means application-layer code must not interpret this value — only infrastructure adapters use it to resolve the URL
- **Use `\Closure(string): string`** (not `callable`) for injectable HTTP fetching — better PHPStan support at max level
- **Handler constructs domain `Pokemon` VO internally**, then maps to `PokemonLevelResult` DTO for return — domain logic stays in domain layer
- **Port DTOs intentionally use domain Value Objects** because Ports are part of Core and share the same dependency boundary. This is standard Hexagonal Architecture: Port→Domain dependency is allowed
- **Infrastructure adapters construct domain VOs** as return types (e.g., `GrowthRateLevelTable`). This is the standard repository/adapter pattern where Infrastructure transitively depends on Domain
- **No anonymous test doubles** — extract named fakes in `tests/Support/` for reuse across test files
- **Test names** use descriptive scenario names: `it_returns_max_level_when_experience_exceeds_all_thresholds()`
- **Level(0) means "undetermined"** — when a pokemon's level cannot be calculated (empty growth rate table or experience below all thresholds), Level(0) is returned, matching the original code's behavior
- **Query objects carry primitives** — `GetPokemonLevel` takes a `string $name`, not a domain VO, keeping Presentation decoupled from Domain. The handler constructs the `PokemonName` VO internally
- **"Integration test" in this context** means a test that wires the message bus with the real handler and fake dependencies — not "boots a framework" (there is no framework to boot)
- **Message bus wiring**: use `MapHandlerResolver` (in `src/Infrastructure/MessageBus/`) to register handler instances, then `QueryDispatcher($resolver)` to dispatch. Handler FQCN = Query FQCN + "Handler" suffix, same namespace
- **`rawurlencode()` on pokemon name** when interpolating into URLs — RFC 3986 compliant
- **Sort GrowthRateLevelTable by experience** (the value being compared against) — because `levelFor()` iterates comparing base_experience against each item's experience threshold
- **MapHandlerResolver lives in production code** (`src/Infrastructure/MessageBus/`) — both tests and `bin/run.php` import from there. No duplicates in test code

---

## Task 0 - Project Setup & Message Bus Installation

- **Priority**: HIGH
- **Dependencies**: None
- **Owner**: @developer
- **Description**: Set up the development environment inside the Docker container. Add the private `get-e/message-bus` repository to `composer.json` and install the `dev-feature/dummy-adapter` branch. Verify `require-dev` dependencies are compatible with PHP 8.4 — PHPUnit 9 is EOL and requires upgrade to 11+; `symplify/*` and `approvals/*` packages are incompatible and must be removed. Read `vendor/get-e/message-bus/README.ai.md` and report the message bus API back to the PO. Rename the composer package. Create a minimal Makefile.

### Acceptance criteria

- Docker container running with PHP 8.4
- `composer.json` package name is `gete/poke-parser` (lowercase, hyphens only)
- `composer.json` contains the VCS repository entry for `git@github.com:GET-E/message-bus.git` (and `get-e/php-overlay` if required as a transitive dependency)
- `get-e/message-bus:dev-feature/dummy-adapter` is installed
- All `require-dev` dependencies compatible with PHP 8.4; PHPUnit upgraded to 11+ (update `phpunit.xml` schema: `<source>` instead of `<coverage>`)
- `approvals/approval-tests`, `symplify/easy-coding-standard`, `symplify/phpstan-extensions` removed
- `phpstan.neon` updated to not reference removed packages
- Original `bin/run.php` still runs and produces the expected output for the README example
- Developer reports the message bus Dummy adapter API back to the PO: how to construct the bus, register a handler, dispatch a query — in a non-Laravel context
- `phpunit.xml` updated with separate testsuites for `Unit` (`./tests/Unit`) and `Integration` (`./tests/Integration`)
- Minimal `Makefile` with targets: `test` (runs PHPUnit), `static` (runs PHPStan), `coverage` (runs PHPUnit with coverage report)

---

## Task 1 - Domain Value Objects & Level Calculation

- **Priority**: HIGH
- **Dependencies**: Task 0
- **Owner**: @developer
- **Description**: Create the domain model as pure Value Objects with zero framework dependencies. Constructors must normalize input (trim, lowercase) and validate invariants with explicit `if (!...) { throw ... }` guards — no `assert()`. The level calculation behavior must live on the `GrowthRateLevelTable` collection that owns the data. The max-level bug must be fixed. The collection must sort items by experience ascending in the constructor — because `levelFor()` iterates comparing the given base_experience against each item's experience threshold, so items must be ordered by that threshold.

### Acceptance criteria

- `PokemonName`: final readonly VO wrapping a non-empty, trimmed, lowercased string
- `BaseExperience`: final readonly VO wrapping a non-negative integer
- `SpeciesName`: final readonly VO wrapping a non-empty, trimmed, lowercased string
- `Level`: final readonly VO wrapping a non-negative integer. Level(0) is valid and means "undetermined"
- `GrowthRateLevel`: final readonly VO with fields `Level $level` and `int $minimumExperience` (non-negative). The `$minimumExperience` is the threshold used for sorting and comparison in `GrowthRateLevelTable::levelFor()`
- `GrowthRateLevelTable`: final readonly collection of `GrowthRateLevel` items sorted by experience ascending in the constructor (resilient to unordered input), with a `levelFor(BaseExperience): Level` method that:
  - Returns Level(0) when the table is empty
  - Returns the correct level when experience falls between two thresholds
  - Returns the **maximum level** when experience exceeds all thresholds (bug fix — original returns 0)
  - Returns Level(0) when experience is below all thresholds
- `Pokemon`: final readonly VO aggregating `PokemonName`, `BaseExperience`, `SpeciesName`, `Level`
- All domain classes are `final readonly`
- Unit tests in `tests/Unit/Core/Component/Pokemon/Domain/` cover all invariants, edge cases, and the bug fix
- A specific test case proves the max-level bug fix: given a table with levels 1–100, and experience exceeding the level-100 threshold, `levelFor()` returns Level(100), not Level(0)
- Domain classes have zero framework dependencies

---

## Task 2 - Port Interfaces & DTOs

- **Priority**: HIGH
- **Dependencies**: Task 1
- **Owner**: @developer
- **Description**: Define the port interfaces the application layer needs, along with typed DTOs. `GrowthRateReference` has a `value(): string` method; the opacity means application-layer code must not interpret the value. Port interfaces must not expose transport concepts.

### Acceptance criteria

- `GrowthRateReference`: final readonly VO with a `value(): string` method. Constructor validates the internal value is non-empty
- `PokemonDataResult`: final readonly DTO with fields: `PokemonName $name`, `BaseExperience $baseExperience`, `SpeciesName $speciesName`, `GrowthRateReference $growthRateReference`
- `PokemonDataProvider`: interface with method `getByName(PokemonName $name): PokemonDataResult`
- `GrowthRateLevelProvider`: interface with method `getByReference(GrowthRateReference $reference): GrowthRateLevelTable`
- `PokeApiException`: final runtime exception defined at the port level for data-fetching failures
- Port interfaces do not expose transport concepts (no URLs, headers, or connection strings in signatures)
- Unit tests in `tests/Unit/Core/Port/PokeApi/` for `GrowthRateReference` and `PokemonDataResult` construction and validation
- Named fakes in `tests/Support/`: `InMemoryPokemonDataProvider`, `InMemoryGrowthRateLevelProvider`

---

## Task 3 - Application Layer: Query Object & Handler

- **Priority**: HIGH
- **Dependencies**: Task 1, Task 2
- **Owner**: @developer
- **Description**: Create a query object and handler that orchestrate fetching pokemon data, resolving the growth rate, and calculating the level. The handler constructs a `Pokemon` domain VO internally, then maps to `PokemonLevelResult` DTO for return. The handler must be dispatched through the `get-e/message-bus` Dummy adapter. Adjust implementation to use the exact API reported by the developer in Task 0.

### Acceptance criteria

- `GetPokemonLevel`: query object taking a `string $name` (primitive — not a domain VO, keeping Presentation decoupled from Domain). Implements `GetE\MessageBus\Port\QueryBus\Query<PokemonLevelResult>`
- `GetPokemonLevelHandler`: handles `GetPokemonLevel`, orchestrates: (1) construct `PokemonName` from the query's string, (2) fetch pokemon data via `PokemonDataProvider`, (3) fetch growth rate levels via `GrowthRateLevelProvider`, (4) calculate level via `GrowthRateLevelTable::levelFor()`, (5) construct domain `Pokemon` VO, (6) map to `PokemonLevelResult` DTO and return it. Handler naming convention: same namespace as the query, FQCN = Query FQCN + "Handler"
- `PokemonLevelResult`: final readonly application-layer DTO with fields: `string $name`, `int $baseExperience`, `string $speciesName`, `int $level`
- The handler is dispatched through the message bus (not instantiated directly) in tests
- Integration test in `tests/Integration/Core/Component/Pokemon/Application/Query/GetPokemonLevel/` dispatches the query through the message bus with `InMemoryPokemonDataProvider` and `InMemoryGrowthRateLevelProvider`, asserts the returned `PokemonLevelResult`
- Integration test includes an error-path case: `PokeApiException` propagates when a provider throws

---

## Task 4 - Infrastructure Adapters (PokeAPI HTTP)

- **Priority**: HIGH
- **Dependencies**: Task 2
- **Owner**: @developer
- **Description**: Implement port interfaces as HTTP adapters. Use an injectable `\Closure(string): string` for HTTP fetching. Validate HTTPS URL schemes on any URL received from API responses before fetching. Validate external JSON defensively before mapping to domain types. Apply `rawurlencode()` on the pokemon name before interpolating into the URL.

### Acceptance criteria

- `HttpPokemonDataProvider`: implements `PokemonDataProvider`, makes 2 HTTP calls (GET /pokemon/{name} + GET {species_url}), returns `PokemonDataResult` with `GrowthRateReference`. Applies `rawurlencode()` on the pokemon name when building the URL. Validates HTTPS scheme on species URL from API response before fetching
- `HttpGrowthRateLevelProvider`: implements `GrowthRateLevelProvider`, makes 1 HTTP call (GET {growth_rate_url}), returns `GrowthRateLevelTable`. Validates HTTPS scheme on the `GrowthRateReference::value()` URL before fetching (defense in depth)
- Both adapters accept a `\Closure(string): string` in their constructor
- Both adapters validate external JSON defensively (type-check every field with explicit `if` guards) before mapping to domain types
- Both adapters throw `PokeApiException` on failures (invalid JSON, missing fields, non-HTTPS URLs, HTTP errors)
- `FakeHttpClient` in `tests/Support/`: a named fake class with `__invoke(string $url): string` method that maps URL patterns to canned JSON response strings. Reusable across infrastructure adapter tests
- Integration tests in `tests/Integration/Infrastructure/PokeApi/Http/` use `FakeHttpClient` with canned JSON, asserting correct domain mapping AND all error paths (invalid JSON, missing fields, non-HTTPS URLs)
- Every defensive validation branch in the adapters must be covered by at least one test (aim for 100% coverage of these classes)

---

## Task 5 - Infrastructure: MapHandlerResolver

- **Priority**: HIGH
- **Dependencies**: Task 0
- **Owner**: @developer
- **Description**: Create the production `MapHandlerResolver` that maps handler FQCNs to pre-configured handler instances. This lives in `src/Infrastructure/MessageBus/` so both `bin/run.php` and tests can import from the same location. Unit-test it.

### Acceptance criteria

- `MapHandlerResolver`: final readonly class implementing the message-bus `HandlerResolver` interface. Constructor takes `array<class-string, object>`. `resolve(string $handlerFqcn): object` returns the mapped instance or throws `\RuntimeException` if not found
- Located at `src/Infrastructure/MessageBus/MapHandlerResolver.php`
- Unit test in `tests/Unit/Infrastructure/MessageBus/MapHandlerResolverTest.php` covering: happy path (resolves known handler), error path (throws for unknown handler FQCN)
- No duplicate `MapHandlerResolver` in test code — tests import from the production namespace

---

## Task 6 - Presentation Layer: CLI Formatter & Entry Point

- **Priority**: HIGH
- **Dependencies**: Task 3, Task 4, Task 5
- **Owner**: @developer
- **Description**: Create the output formatter and rewrite `bin/run.php` as a thin entry point that wires the message bus Dummy adapter, dispatches one query per pokemon name, and formats the results. Handle errors gracefully.

### Acceptance criteria

- `PokemonFormatter`: formats a `PokemonLevelResult` to the string `"{name} {experience} {species} {level}"`. Formatting logic is in a separate class under `src/Presentation/Cli/`, not in the entry point
- `bin/run.php`: thin CLI entry point that:
  - Reads pokemon names from `$argv`
  - Wires the message bus Dummy adapter with `GetPokemonLevelHandler` and its real HTTP dependencies (using `MapHandlerResolver` from `src/Infrastructure/MessageBus/`)
  - Dispatches one `GetPokemonLevel` query per pokemon name through the message bus
  - Formats each result with `PokemonFormatter`
  - Outputs newline-separated results to stdout, with NO trailing newline (matching original behavior)
  - Handles `PokeApiException` per pokemon: prints error to stderr, continues to next pokemon
  - When called with no arguments: exits with code 0 and no output
  - Exit code: 0 when all pokemon succeed (or no arguments), 1 when any pokemon fails
- The refactored code produces byte-identical output to the original for the README example input (`ivysaur bulbasaur pikachu ditto`). The README inputs do not trigger the max-level bug, so output is identical despite the fix
- Unit test for `PokemonFormatter` in `tests/Unit/Presentation/Cli/`

---

## Task 7 - Static Analysis, Test Coverage & Smoke Test

- **Priority**: HIGH
- **Dependencies**: Tasks 1–6
- **Owner**: @developer
- **Description**: Ensure PHPStan passes at max level with 0 errors. Ensure test coverage is **100%** of `src/`. Add one end-to-end smoke test. Add tests for any uncovered code paths. Coverage must not be below 100% — target every defensive guard and error branch.

### Acceptance criteria

- `phpstan analyse` at max level: 0 errors
- PHPUnit coverage of `src/` = **100% line coverage**
- All tests pass with no warnings, notices, or deprecation notices
- One integration smoke test (`tests/Integration/SmokeTest.php`) verifies the full pipeline: wires Dummy adapter with `FakeHttpClient` → dispatches query → handler → adapter → domain → DTO → formatter → output string matches expected result
- Every uncovered branch (defensive guards, error paths, exception construction) has a targeted test
- All `use` imports — no FQN (fully qualified names) in source or test code

---

## Lessons Incorporated from Prior Iterations (v9 MEMORY.md)

- **Transitive dependency**: `get-e/message-bus` requires `get-e/php-overlay` (also private), needs its own VCS repository entry in composer.json
- **PHPUnit 9 → 11**: Required for PHP 8.4; uses `<source>` instead of `<coverage>` in phpunit.xml
- **Removed packages**: `approvals/approval-tests`, `symplify/easy-coding-standard`, `symplify/phpstan-extensions` (all incompatible with PHP 8.4)
- **Docker flags**: Use `--rm` only, NOT `-it` (non-interactive subagent sessions)
- **`\Closure(string): string`** (not `callable`) for HTTP injection — PHPStan max level requirement
- **HTTPS validation** on URLs from API responses before fetching
- **`json_decode()` with `JSON_THROW_ON_ERROR`**, then type-check every field
- **Handler convention**: handler FQCN = query FQCN + "Handler", same namespace. Method: `__invoke()` or `handle()`
- **MapHandlerResolver in production code** — not duplicated in tests
- **No trailing newline** in output (matching original)
- **`@implements Query<PokemonLevelResult>`** PHPDoc on query class for PHPStan generics
- **`@implements QueryHandler<PokemonLevelResult>`** PHPDoc on handler class for PHPStan generics
- **`json_encode()` in test files needs `JSON_THROW_ON_ERROR`** for PHPStan to narrow return type to `string`
