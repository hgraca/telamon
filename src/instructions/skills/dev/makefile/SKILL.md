---
name: telamon.makefile
description: "Makefile lifecycle commands: running CLI commands inside containers, starting and stopping development environment. Use when running application commands, starting dev environment, or extending build lifecycle."
---

# Makefile

## When to Apply

- Running CLI commands in application
- Starting or stopping development environment
- Extending build lifecycle with new commands

## Rules

Never bypass Makefile. Extend it if lifecycle changes required.

- Run all CLI commands inside `app` container via `make run CMD="..."`

## Lifecycle commands

- `make install`: Full installation (first-time setup or reinstall)
- `make up`: Boot services (no installation)
- `make run CMD='...'`: Run command inside application container
- `make down`: Stop development environment
- `make update`: Upgrade all tools + install any missing

## See also

- `telamon.testing` skill