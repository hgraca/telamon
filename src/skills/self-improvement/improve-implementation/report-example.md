# Quality Report: pokeapi-v1 vs pokeapi-v2

## Epic: Kata - PokeAPI Parser Refactoring

---

## 1. Approach Overview

### V1 — Rich Domain, Fine-Grained Port

V1 builds a full domain model with Value Objects (PokemonName, BaseExperience, SpeciesName, Level, ExperienceThreshold, GrowthRate) and a dedicated entity (`Pokemon`) with a factory method that encapsulates level calculation. The port layer exposes three fine-grained fetch methods mirroring the external API's multi-step workflow (`fetchPokemon`, `fetchSpecies`, `fetchGrowthRate`), each returning typed DTOs. The application use case orchestrates the three calls, maps port DTOs into domain objects, and returns a flat `PokemonDetails` DTO for the presentation layer.

The team chose to **fix the known level-calculation bug** (experience exceeding all thresholds now returns the highest level instead of 0).

**Source files: 18 | Test files: 12 | Total: 30 files**

### V2 — Lean Domain, Coarse-Grained Port

V2 uses a minimal domain model. `Pokemon` is a simple readonly data class with primitive properties. There are no Value Objects. The port layer exposes a single method (`fetchPokemonData`) that hides the entire API-chaining workflow, returning a typed array. `LevelCalculator` is injected as a dependency into the application service. The infrastructure adapter does extensive defensive validation of every API response field and uses `urlencode()` for safe URL building.

The team chose to **preserve the known bug** as a deliberate refactoring discipline decision (behavior preservation).

**Source files: 8 | Test files: 8 | Total: 16 files**

---

## 2. Comparison by Dimension

| Dimension | V1 | V2 |
|---|---|---|
| **Domain richness** | 8 Value Objects + entity with factory | 1 readonly data class, no VOs |
| **Port design** | 3 methods + 5 DTOs (mirrors API structure) | 1 method returning typed array (hides API) |
| **Dependency injection** | LevelCalculator hidden inside entity factory | LevelCalculator injected into application service |
| **Bug handling** | Fixed (returns highest level) | Preserved (returns 0, documented) |
| **Infrastructure test strategy** | Calls real PokeAPI (network-dependent) | FakeStreamWrapper (deterministic, offline) |
| **Input validation** | Value Objects reject invalid data at construction | No domain-level validation; infrastructure validates API response shape |
| **URL safety** | No encoding | Uses `urlencode()` |
| **PHP version** | ^8.4 | ^8.2 |
| **Test suite split** | Unit + Integration (proper separation) | All under Unit (including infrastructure) |
| **Application API** | `execute(string $name): PokemonDetails` (one at a time) | `execute(string ...$names): Pokemon[]` (variadic) |
| **Composer metadata** | Package name is a leftover from template | Properly named |

---

## 3. Strong Points

### V1

- **Self-validating domain**: Value Objects prevent invalid states at construction time (empty names, negative experience, invalid thresholds). Invalid data cannot silently flow through the system.
- **Bug fix demonstrates understanding**: Fixing the edge case where experience exceeds all thresholds shows the developer identified a real correctness problem and solved it. From a product perspective, users get correct output.
- **Typed port DTOs**: The port layer uses dedicated data classes (`PokemonData`, `SpeciesData`, `GrowthRateData`, `GrowthRateLevelEntry`) instead of raw arrays, giving compile-time safety and IDE support.
- **Application returns a flat DTO**: The `PokemonDetails` DTO decouples the presentation layer from domain internals.
- **Use case integration test with stub**: `InMemoryPokeApiClient` enables testing the use case's orchestration logic without network calls.
- **Good test naming**: Tests follow the `it_*` convention and describe scenarios clearly.

### V2

- **Clean port abstraction**: A single `fetchPokemonData()` method hides the multi-step API workflow entirely. The application layer has no concept of "species URL" or "growth rate URL" — the port owns that complexity.
- **Proper dependency injection**: `LevelCalculator` is injected into `GetPokemonDetails`, making both testable and replaceable independently.
- **Deterministic infrastructure tests**: The `FakeStreamWrapper` approach intercepts PHP's stream layer, testing the real `PokeApiClient` code paths without any network call. No test is flaky.
- **Thorough error path coverage**: 12 infrastructure test cases covering missing species data, empty URLs, malformed JSON, missing growth rate, and missing fields — far more exhaustive than V1's 4 infrastructure tests.
- **Variadic execute**: `execute(string ...$names)` is a cleaner API for batch operations; the loop lives in the service, not in the caller.
- **Defensive infrastructure**: Every field from the API response is validated with `is_array`, `is_string`, `is_int` checks before use.
- **URL encoding**: `urlencode($name)` protects against special characters in pokemon names.

---

## 4. Weak Points

### V1

- **Hidden dependency in entity**: `Pokemon::fromGrowthRate()` internally instantiates `LevelCalculator`. This couples the entity to the calculator, makes the dependency invisible, and prevents swapping the calculation strategy without modifying the entity.
- **Port leaks transport details**: The port interface passes URLs between methods (`fetchSpecies(string $url)`, `fetchGrowthRate(string $url)`). The concept of "URL" belongs to the infrastructure, not the port.
- **Real-API integration test**: `HttpPokeApiClientTest` calls the live PokeAPI. This makes the test slow, flaky, and impossible to run offline. It also risks breaking when the API changes data values.
- **No URL encoding**: API calls are made without encoding the pokemon name, which could fail for names with special characters.
- **Leftover template metadata**: `composer.json` still declares `"name": "emilybache/gilded-rose-refactoring-kata"`.
- **Over-engineered for scope**: 18 source files for a kata-sized problem. The Value Object count (6+) introduces friction without proportional benefit given the project size.

### V2

- **Anemic domain model**: `Pokemon` is just a data carrier with no behavior or validation. Nothing prevents creating a Pokemon with negative experience, an empty name, or level -5. The domain layer does not protect its own invariants.
- **Port returns untyped array**: `fetchPokemonData()` returns `array{baseExperience: int, speciesName: string, growthRateLevels: GrowthRateLevel[]}`. While documented, this is not enforced by the type system; a typo in an array key would be a runtime error, not a compile-time error.
- **Bug preserved, not fixed**: The known bug (level returns 0 when experience exceeds max threshold) is explicitly kept. While this is a valid refactoring-discipline choice, from a product perspective it means the output is incorrect for high-experience pokemon.
- **Reflection-based tests**: Several infrastructure tests use `ReflectionClass` to verify interface structure (e.g., "has a method accepting a string parameter"). These test implementation details rather than behavior, and add no real safety.
- **Test suite mislabeling**: Infrastructure tests using `FakeStreamWrapper` are placed in `tests/Unit/` rather than a separate integration suite, blurring the test-type boundary.
- **Exception in Infrastructure namespace**: `ApiException` lives in `Infrastructure\PokeApi`, which means the port interface can only reference it via `\RuntimeException` in its PHPDoc. A port-level exception would be cleaner.
- **Classes not final**: Domain and application classes are `class` instead of `final class`, which weakens encapsulation guarantees.
- **Vendor committed**: The `vendor/` directory appears to be tracked in the repository.

---

## 5. Grades

| Solution | Grade |
|---|---|
| **V1** | **73 / 100** |
| **V2** | **68 / 100** |

---

## 6. Grade Justification

The **5-point gap** comes from three factors where V1 outperforms V2, partially offset by two factors where V2 is stronger:

**V1 earns points over V2 (+9):**

1. **Domain protection** (+4): V1's Value Objects prevent invalid states at construction. In V2, any caller can create a `Pokemon` with `baseExperience: -999` or `name: ''`. In a production system, this class of bug is expensive. Domain self-validation is a core quality signal.

2. **Correctness / bug fix** (+3): V1 identified and fixed the level-calculation edge case. From a product perspective, this means V1 delivers correct output to users. V2 explicitly delivers known-incorrect output for high-experience pokemon. Even in a refactoring kata context, recognizing and fixing correctness issues adds value.

3. **Typed port contracts** (+2): V1 uses dedicated DTO classes in the port layer. V2 uses a raw array. The DTO approach catches contract violations at the type-system level rather than at runtime.

**V2 earns points over V1 (-4):**

1. **Port abstraction quality** (-2): V2's single-method port completely hides the API's multi-call workflow. V1's port forces the application layer to know about species URLs and growth rate URLs — transport-layer details that don't belong in the port.

2. **Test determinism** (-2): V2's `FakeStreamWrapper` approach tests the real infrastructure code without network calls. V1's `HttpPokeApiClientTest` depends on a live external API, making the test suite fragile and unsuitable for CI.

**Neutral / offsetting:**

- V1's hidden `LevelCalculator` dependency inside the entity and V2's proper injection of it roughly cancel out V1's otherwise stronger domain model.
- V2's more exhaustive error-path coverage in infrastructure tests is offset by V1's broader behavioral test coverage across the domain layer.

---

## 7. Summary

Both solutions demonstrate competent refactoring of the original kata. V1 invested heavily in domain modeling and correctness, building a richer, safer system at the cost of more complexity and some architectural missteps (hidden dependency, leaky port). V2 prioritized clean port design, testability, and defensive infrastructure at the cost of domain protection and known-incorrect output.

For a production system, V1's approach (Value Objects, bug fix) would be more sustainable. For a rapid iteration context, V2's simplicity and test determinism would be more practical. Neither solution is wrong — they represent different trade-off philosophies applied to the same problem.
