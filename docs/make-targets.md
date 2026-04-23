---
layout: page
title: Commands
description: All available telamon CLI commands and make targets.
nav_section: docs
---

## CLI commands

After installing, the `telamon` command is available system-wide from any directory.

| Command | Description |
|---|---|
| `telamon up` | Install host tools + start Docker services |
| `telamon down` | Stop Docker services |
| `telamon restart` | Stop then start |
| `telamon status` | Quick installation status |
| `telamon doctor` | Comprehensive health check (connectivity, config, secrets) |
| `telamon update` | Upgrade all Telamon-managed tools |
| `telamon init [path]` | Initialise a project (default: current directory) |
| `telamon reset [path]` | Remove project wiring, keep storage data |
| `telamon purge [path]` | Remove project wiring **and** storage data |
| `telamon recover-memories [path]` | Extract memories from past session transcripts |
| `telamon uninstall` | Completely remove Telamon (destructive) |
| `telamon help` | Show usage help |

`init`, `reset`, `purge`, and `recover-memories` accept an optional path. If omitted, they use the current directory. Relative paths are resolved correctly:

```bash
cd ~/my-project && telamon init          # initialises ~/my-project
telamon init ~/my-project                # same result, from anywhere
telamon init ../other-project            # relative path works too
```

### recover-memories

Scans the opencode session database for all sessions associated with a project, extracts decisions, patterns, gotchas, and lessons using an LLM, then writes them to both Ogham and the `brain/` markdown files.

```bash
telamon recover-memories                 # incremental — current project
telamon recover-memories ~/my-project    # incremental — specific project
telamon recover-memories --all           # incremental — all initialized projects
telamon recover-memories --full          # full reset — clear existing, reprocess all
telamon recover-memories --dry-run       # preview without making changes
telamon recover-memories --batch-size 10 # larger batches (default: 5)
```

| Flag | Description |
|---|---|
| `--all` | Discover all initialized projects and process each. Prompts for confirmation. |
| `--full` | Full reset: export Ogham backup, clear all memories in the profile, reset `brain/` files from templates, then reprocess every session. |
| `--dry-run` | Show how many sessions would be processed without calling the LLM or writing anything. |
| `--batch-size N` | Number of sessions per LLM call (default: 5). Larger batches are more token-efficient but risk truncation on very long sessions. |

**Incremental by default.** The command tracks which sessions have been processed in a `.recover-memories-<project>.json` file under `thinking/`. On subsequent runs, only new sessions are processed. Use `--full` to start from scratch.

**Model selection.** The command uses the `medium_model` setting from `telamon.ini`. On first run, it prompts interactively with suggestions derived from the project's `model` and `small_model` in `opencode.jsonc`. See [Configuration](configuration.md#per-project-settings).

**Typical runtime.** For a project with 200 sessions at batch-size 5: ~40 LLM calls, ~7–10 minutes.

---

## Under the hood: make targets

The `telamon` CLI is a thin wrapper around `make` targets. When running from the Telamon directory, you can use `make` directly:

| Target | Description |
|---|---|
| `make up` | Install host tools + start Docker services |
| `make down` | Stop Docker services |
| `make restart` | Stop then start |
| `make status` | Quick installation status |
| `make doctor` | Comprehensive health check |
| `make update` | Upgrade all tools |
| `make init PROJ=<path>` | Initialise a project |
| `make reset PROJ=<path>` | Remove project wiring, keep storage |
| `make purge PROJ=<path>` | Remove wiring and storage |
| `make uninstall` | Completely remove Telamon |
| `make test` | Run the full test suite |

> `make init`, `make reset`, and `make purge` require the `PROJ=` argument. Use the `telamon` CLI for the default-to-cwd convenience.

---

## CLI installation

The `telamon` CLI is installed automatically as part of `make up`. It creates:

- **Symlink**: `~/.local/bin/telamon` → `<telamon-root>/bin/telamon`
- **Linux menu entry**: `~/.local/share/applications/telamon.desktop`
- **macOS app**: `~/Applications/Telamon.app`

The CLI resolves its own symlink chain to find the Telamon root, so it works from any location.
