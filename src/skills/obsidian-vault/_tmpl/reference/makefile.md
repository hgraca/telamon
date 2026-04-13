# MAKEFILE

Never bypass the Makefile. Extend it if lifecycle changes are required.

- Run all CLI commands inside the `app` container via `make run CMD="..."`

## Lifecycle commands

- `make up`: Start the development environment
- `make down`: Stop the development environment
