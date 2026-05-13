# Quality Report: pokeapi-v1 vs pokeapi-v2

## Epic: Kata - PokeAPI Parser Refactoring

---

## 1. Approach Overview

### V1 — Rich Domain, Fine-Grained Port

V1 builds full domain model with Value Objects (PokemonName, BaseExperience, SpeciesName, Level, ExperienceThreshold, GrowthRate) and dedicated entity (`Pokemon`) with factory method encapsulating level calculation. Port layer exposes three fine-grained fetch methods mirroring external API's multi-step workflow (`fetchPokemon`, `fetchSpecies`, `fetchGrowthRate`), each returning typed DTOs. Application use case orchestrates three calls, maps port DTOs into domain objects, returns flat `PokemonDetails` DTO for presentation layer.

Team chose to **fix known level-calculation bug** (experience exceeding all thresholds now returns highest level instead of 0).

**Source files: 18 | Test files: 12 | Total: 30 files**

### V2 — Lean Domain, Coarse-Grained Port

V2 uses minimal domain model. `Pokemon` is simple readonly data class with primitive properties. No Value Objects. Port layer exposes single method (`fetchPokemonData`) hiding entire API-chaining workflow, returning typed array. `LevelCalculator` injected as dependency into application service. Infrastructure adapter does extensive defensive validation of every API response field and uses `urlencode()` for safe URL building.

Team chose to **preserve known bug** as deliberate refactoring discipline decision (behavior preservation).

**Source files: 8 | Test files: 8 | Total: 16 files**

---

## 2. Comparison by Dimension

| Dimension                        | V1                                                      | V2                                                                      |
|----------------------------------|---------------------------------------------------------|-------------------------------------------------------------------------|
| **Domain richness**              | 8 Value Objects + entity with factory                   | 1 readonly data class, no VOs                                           |
| **Port design**                  | 3 methods + 5 DTOs (mirrors API structure)              | 1 method returning typed array (hides API)                              |
| **Dependency injection**         | LevelCalculator hidden inside entity factory            | LevelCalculator injected into application service                       |
| **Bug handling**                 | Fixed (returns highest level)                           | Preserved (returns 0, documented)                                       |
| **Infrastructure test strategy** | Calls real PokeAPI (network-dependent)                  | FakeStreamWrapper (deterministic, offline)                              |
| **Input validation**             | Value Objects reject invalid data at construction       | No domain-level validation; infrastructure validates API response shape |
| **URL safety**                   | No encoding                                             | Uses `urlencode()`                                                      |
| **PHP version**                  | ^8.4                                                    | ^8.2                                                                    |
| **Test suite split**             | Unit + Integration (proper separation)                  | All under Unit (including infrastructure)                               |
| **Application API**              | `execute(string $name): PokemonDetails` (one at a time) | `execute(string ...$names): Pokemon[]` (variadic)                       |
| **Composer metadata**            | Package name is a leftover from template                | Properly named                                                          |

---

## 3. Strong Points

### V1

- **Self-validating domain**: Value Objects prevent invalid states at construction time (empty names, negative experience, invalid thresholds). Invalid data cannot silently flow through system.
- **Bug fix demonstrates understanding**: Fixing edge case where experience exceeds all thresholds shows developer identified real correctness problem and solved it. From product perspective, users get correct output.
- **Typed port DTOs**: Port layer uses dedicated data classes (`PokemonData`, `SpeciesData`, `GrowthRateData`, `GrowthRateLevelEntry`) instead of raw arrays, giving compile-time safety and IDE support.
- **Application returns flat DTO**: `PokemonDetails` DTO decouples presentation layer from domain internals.
- **Use case integration test with stub**: `InMemoryPokeApiClient` enables testing use case's orchestration logic without network calls.
- **Good test naming**: Tests follow `it_*` convention and describe scenarios clearly.

### V2

- **Clean port abstraction**: Single `fetchPokemonData()` method hides multi-step API workflow entirely. Application layer has no concept of "species URL" or "growth rate URL" — port owns that complexity.
- **Proper dependency injection**: `LevelCalculator` injected into `GetPokemonDetails`, making both testable and replaceable independently.
- **Deterministic infrastructure tests**: `FakeStreamWrapper` approach intercepts PHP's stream layer, testing real `PokeApiClient` code paths without any network call. No test flaky.
- **Thorough error path coverage**: 12 infrastructure test cases covering missing species data, empty URLs, malformed JSON, missing growth rate, missing fields — far more exhaustive than V1's 4 infrastructure tests.
- **Variadic execute**: `execute(string ...$names)` cleaner API for batch operations; loop lives in service, not in caller.
- **Defensive infrastructure**: Every field from API response validated with `is_array`, `is_string`, `is_int` checks before use.
- **URL encoding**: `urlencode($name)` protects against special characters in pokemon names.

---

## 4. Weak Points

### V1

- **Hidden dependency in entity**: `Pokemon::fromGrowthRate()` internally instantiates `LevelCalculator`. Couples entity to calculator, makes dependency invisible, prevents swapping calculation strategy without modifying entity.
- **Port leaks transport details**: Port interface passes URLs between methods (`fetchSpecies(string $url)`, `fetchGrowthRate(string $url)`). Concept of "URL" belongs to infrastructure, not port.
- **Real-API integration test**: `HttpPokeApiClientTest` calls live PokeAPI. Makes test slow, flaky, impossible to run offline. Also risks breaking when API changes data values.
- **No URL encoding**: API calls made without encoding pokemon name, could fail for names with special characters.
- **Leftover template metadata**: `composer.json` still declares `"name": "emilybache/gilded-rose-refactoring-kata"`.
- **Over-engineered for scope**: 18 source files for kata-sized problem. Value Object count (6+) introduces friction without proportional benefit given project size.

### V2

- **Anemic domain model**: `Pokemon` is data carrier with no behavior or validation. Nothing prevents creating Pokemon with negative experience, empty name, or level -5. Domain layer does not protect its own invariants.
- **Port returns untyped array**: `fetchPokemonData()` returns `array{baseExperience: int, speciesName: string, growthRateLevels: GrowthRateLevel[]}`. While documented, not enforced by type system; typo in array key would be runtime error, not compile-time error.
- **Bug preserved, not fixed**: Known bug (level returns 0 when experience exceeds max threshold) explicitly kept. While valid refactoring-discipline choice, from product perspective output is incorrect for high-experience pokemon.
- **Reflection-based tests**: Several infrastructure tests use `ReflectionClass` to verify interface structure (e.g., "has method accepting string parameter"). Tests implementation details rather than behavior, add no real safety.
- **Test suite mislabeling**: Infrastructure tests using `FakeStreamWrapper` placed in `tests/Unit/` rather than separate integration suite, blurring test-type boundary.
- **Exception in Infrastructure namespace**: `ApiException` lives in `Infrastructure\PokeApi`, meaning port interface can only reference it via `\RuntimeException` in PHPDoc. Port-level exception would be cleaner.
- **Classes not final**: Domain and application classes are `class` instead of `final class`, weakening encapsulation guarantees.
- **Vendor committed**: `vendor/` directory appears tracked in repository.

---

## 5. Grades

| Solution | Grade        |
|----------|--------------|
| **V1**   | **73 / 100** |
| **V2**   | **68 / 100** |

---

## 6. Grade Justification

**5-point gap** comes from three factors where V1 outperforms V2, partially offset by two factors where V2 is stronger:

**V1 earns points over V2 (+9):**

1. **Domain protection** (+4): V1's Value Objects prevent invalid states at construction. In V2, any caller can create `Pokemon` with `baseExperience: -999` or `name: ''`. In production system, this class of bug expensive. Domain self-validation is core quality signal.

2. **Correctness / bug fix** (+3): V1 identified and fixed level-calculation edge case. From product perspective, V1 delivers correct output to users. V2 explicitly delivers known-incorrect output for high-experience pokemon. Even in refactoring kata context, recognizing and fixing correctness issues adds value.

3. **Typed port contracts** (+2): V1 uses dedicated DTO classes in port layer. V2 uses raw array. DTO approach catches contract violations at type-system level rather than at runtime.

**V2 earns points over V1 (-4):**

1. **Port abstraction quality** (-2): V2's single-method port completely hides API's multi-call workflow. V1's port forces application layer to know about species URLs and growth rate URLs — transport-layer details that don't belong in port.

2. **Test determinism** (-2): V2's `FakeStreamWrapper` approach tests real infrastructure code without network calls. V1's `HttpPokeApiClientTest` depends on live external API, making test suite fragile and unsuitable for CI.

**Neutral / offsetting:**

- V1's hidden `LevelCalculator` dependency inside entity and V2's proper injection roughly cancel out V1's otherwise stronger domain model.
- V2's more exhaustive error-path coverage in infrastructure tests offset by V1's broader behavioral test coverage across domain layer.

---

## 7. Summary

Both solutions demonstrate competent refactoring of original kata. V1 invested heavily in domain modeling and correctness, building richer, safer system at cost of more complexity and some architectural missteps (hidden dependency, leaky port). V2 prioritized clean port design, testability, and defensive infrastructure at cost of domain protection and known-incorrect output.

For production system, V1's approach (Value Objects, bug fix) more sustainable. For rapid iteration context, V2's simplicity and test determinism more practical. Neither solution wrong — they represent different trade-off philosophies applied to same problem.
