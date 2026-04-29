---
name: telamon.makefile
description: "Makefile lifecycle commands: running CLI commands inside containers, starting and stopping the development environment. Use when running application commands, starting the dev environment, or extending the build lifecycle."
---

# Makefile

## When to Apply

- Running CLI commands in the application
- Starting or stopping the development environment
- Extending the build lifecycle with new commands

## Rules

Never bypass the Makefile. Extend it if lifecycle changes are required.

- Run all CLI commands inside the `app` container via `make run CMD="..."`

## Lifecycle commands

- `make install`: Full installation (first-time setup or reinstall)
- `make up`: Boot services (no installation)
- `make run CMD='...'`: Run a command inside the application container
- `make down`: Stop the development environment
- `make update`: Upgrade all tools + install any missing

## See also

- `telamon.testing` skill
