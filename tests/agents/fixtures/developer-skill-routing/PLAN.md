# Plan — Skill Routing Test Fixture

**Status**: FINAL

## Tasks

1. **Implement CreateUser command handler** — PHP command handler in `src/Application/User/CreateUserHandler.php`
2. **Create REST endpoint** — GET `/api/v1/users` in `src/Infrastructure/Http/UserController.php`
3. **Create ProcessPayment use case** — Command, CommandHandler, and tests using CQRS + message bus
4. **Write PHPUnit tests** — Integration tests for `UserRepository` in `tests/`
5. **Create event handler** — `SendWelcomeEmailHandler` dispatched via message bus on `UserRegistered`
6. **Implement multi-file notification feature** — Spans domain entity, application handler, and infrastructure adapter
