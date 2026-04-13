# PHP UNIVERSAL RULES

## Strict Typing

- Always use `declare(strict_types=1);` at the head of every `.php` file
- Always use curly braces for control structures, even for single-line bodies
- No raw `DateTime` — use Carbon

## Constructors

- Use PHP 8 constructor property promotion: `public function __construct(public GitHub $github) { }`
- Do not allow empty `__construct()` with zero parameters unless the constructor is private

## Type Declarations

- Always use explicit return type declarations for methods and functions
- Use appropriate PHP type hints for all method parameters

```php
protected function isAccessible(User $user, ?string $path = null): bool
{
    ...
}
```

## Enums

- Keys in upper snake case: `FAVORITE_PERSON`, `BEST_LAKE`, `MONTHLY`

## Comments

- Prefer PHPDoc blocks over inline comments
- Never use inline comments unless the logic is exceptionally complex

## PHPDoc Blocks

- Use phpstan array shapes to document arrays
- Array shapes used in several places: define as local phpstan type
- Array shapes used across files: define as custom phpstan type in owner class, import where needed
- Array shapes crossing module boundaries: convert to DTO
