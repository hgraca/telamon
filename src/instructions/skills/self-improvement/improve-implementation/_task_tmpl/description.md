# Kata: Poke API parser

## Solve the challenge

All commands MUST run inside the project's Docker container (see the kata README.md for the Docker setup command).

Make the project require `get-e/message-bus:dev-main`,
you will need to add the private repositories to composer.json:
```php
        {"type": "vcs", "url": "git@github.com:GET-E/message-bus.git"},
        {"type": "vcs", "url": "git@github.com:GET-E/php-overlay.git"}
```

Read the `vendor/get-e/message-bus/README.ai.md` to know how to use the message bus.

Read the project's README.md and develop the solution to the challenge, 
using the `Dummy` adapter of the message bus to dispatch commands and query objects in sync.

### Definition of done

Phase 1 is complete when:
- The refactored code produces correct output for the example in the README
- All tests pass
- Static analysis passes at maximum level
- Test coverage is at least 90% of the src/ directory

## Phase 2: Post-challenge tasks

Document all interactions between agents that happened while planning and implementing this epic during this session, in `interactions.md`.
Use `.ai/tasks/kata/interactions.template.md` as a template.
The report must contain:
   - Interaction Flow Diagram
   - Statistics summary
   - The amount of agent time it took (excluding time waiting for human stakeholder input)
