---
layout: page
title: Telamon cli
description: All available telamon CLI commands and make targets.
nav_section: docs
---

## CLI commands

After installing, the `telamon` command is available system-wide from any directory.

| Command                            | Description                                                |
|------------------------------------|------------------------------------------------------------|
| `telamon up`                       | Install host tools + start Docker services                 |
| `telamon down`                     | Stop Docker services                                       |
| `telamon restart`                  | Stop then start                                            |
| `telamon status`                   | Quick installation status                                  |
| `telamon doctor`                   | Comprehensive health check (connectivity, config, secrets) |
| `telamon update`                   | Upgrade all Telamon-managed tools                          |
| `telamon init [path]`              | Initialise a project (default: current directory)          |
| `telamon reset [path]`             | Remove project wiring, keep storage data                   |
| `telamon purge [path]`             | Remove project wiring **and** storage data                 |
| `telamon recover-memories [path]`  | Extract memories from past session transcripts             |
| `telamon stats [opts]`             | Query tool usage statistics                                |
| `telamon module add <url-or-path>` | Register a module from a git URL or local path             |
| `telamon module remove <name>`     | Remove a registered module by name                         |
| `telamon module list`              | Show all registered modules with clone status              |
| `telamon module sync`              | Re-wire all modules into all initialized projects          |
| `telamon uninstall`                | Completely remove Telamon (destructive)                    |
| `telamon help`                     | Show usage help                                            |

`init`, `reset`, `purge`, and `recover-memories` accept an optional path. If omitted, they use the current directory. Relative paths are resolved correctly:

```bash
cd ~/my-project && telamon init          # initialises ~/my-project
telamon init ~/my-project                # same result, from anywhere
telamon init ../other-project            # relative path works too
```

### init

`telamon init [path]` wires the project for Telamon and, as the **last step**, auto-generates `<PROJ>/.ai/telamon/memory/project-rules/description.md` by invoking the `telamon.explore-project` skill via `opencode run`. The description is the canonical project map that every future agent session reads at bootstrap.

**Idempotency.** Init checks whether `description.md` already exists and is non-empty. If yes, exploration is skipped. To refresh the description after the repo has drifted, delete (or empty) `description.md` and re-run `telamon init`, or invoke the `telamon.explore-project` skill manually from an agent session.

**Missing `opencode`.** If `opencode` is not on `PATH`, init prints a warning, skips exploration, and exits 0 — exploration is an enhancement, not a hard requirement.

**Known limitations.**

- No timeout: the exploration call blocks until `opencode run` returns. On very large repositories the wall-clock can be several minutes. Press Ctrl-C to abort init; description generation can be retried later.
- No `--force-explore` flag: re-exploration is opt-in via deleting `description.md`. A flag may be added later.
- `opencode run` failures are logged as warnings, not errors — init still exits 0 so that exploration failure does not block project wiring.

```bash
telamon init                              # auto-explores if description.md is missing
rm .ai/telamon/memory/project-rules/description.md && telamon init   # refresh
```

### recover-memories

Scans the opencode session database for all sessions associated with a project, extracts decisions, patterns, gotchas, and lessons using an LLM, then writes them to the `brain/` markdown files.

```bash
telamon recover-memories                 # incremental — current project
telamon recover-memories ~/my-project    # incremental — specific project
telamon recover-memories --all           # incremental — all initialized projects
telamon recover-memories --full          # full reset — clear existing, reprocess all
telamon recover-memories --dry-run       # preview without making changes
telamon recover-memories --batch-size 10 # larger batches (default: 5)
```

| Flag             | Description                                                                                                                            |
|------------------|----------------------------------------------------------------------------------------------------------------------------------------|
| `--all`          | Discover all initialized projects and process each. Prompts for confirmation.                                                          |
| `--full`         | Full reset: reset `brain/` files from templates, then reprocess every session. |
| `--dry-run`      | Show how many sessions would be processed without calling the LLM or writing anything.                                                 |
| `--batch-size N` | Number of sessions per LLM call (default: 5). Larger batches are more token-efficient but risk truncation on very long sessions.       |

**Incremental by default.** The command tracks which sessions have been processed in a `.recover-memories-<project>.json` file under `thinking/`. On subsequent runs, only new sessions are processed. Use `--full` to start from scratch.

**Model selection.** The command uses the `medium_model` setting from `telamon.jsonc`. On first run, it prompts interactively with suggestions derived from the project's `model` and `small_model` in `opencode.jsonc`. See [Configuration](configuration.md#per-project-settings).

**Typical runtime.** For a project with 200 sessions at batch-size 5: ~40 LLM calls, ~7–10 minutes.

### stats

Queries the tool usage statistics database and exports the results as CSV. Statistics are collected by the stats plugin and stored in a SQLite database at `storage/stats/stats.sqlite`.

```bash
telamon stats                          # export all stats to thinking/ dir
telamon stats --project my-app         # filter by project name
telamon stats --from 2025-01-01        # from date (inclusive)
telamon stats --to 2025-01-31          # to date (inclusive)
telamon stats --out ./report.csv       # custom output path
```

| Flag             | Description                                                                                  |
|------------------|----------------------------------------------------------------------------------------------|
| `--project`      | Filter results to a specific project name                                                    |
| `--from`         | Start date for filtering (ISO format, e.g. `2025-01-01`)                                     |
| `--to`           | End date for filtering (inclusive, e.g. `2025-01-31`)                                         |
| `--out`          | Output file path. If omitted, writes to `thinking/<timestamp>-stats.csv`                     |

**Output columns:** `tool`, `agent`, `skill`, `project`, `timestamp`

The command prints the output file path and row count on completion.

### module

Modules are external git repositories or local directories that provide commands, agents, skills, scripts, and/or plugins. When you add a module, Telamon clones it into `vendor/<org>/<repo>/` (for git URLs) or creates a symlink in `vendor/` pointing to the local directory, then wires symlinks into every initialized project's `.opencode/` directory — the same nested-set pattern used for Telamon's own files.

Each module gets its own namespace inside `.opencode/`:

```text
<project>/
  .opencode/
    skills/
      telamon/       → <telamon-root>/src/skills      (built-in)
      addyosmani/    → vendor/addyosmani/agent-skills/skills
      my-module/     → vendor/acme/my-module/skills
    agents/
      telamon/       → <telamon-root>/src/agents
      addyosmani/    → vendor/addyosmani/agent-skills/agents
```

```bash
telamon module add <url-or-path> [options]   # clone/link + register + wire
telamon module remove <name>                 # unregister + unwire + delete/unlink
telamon module list                          # show all modules
telamon module sync                          # re-wire all modules to all projects
```

#### Options for `module add`

| Flag          | Description                                                            |
|---------------|------------------------------------------------------------------------|
| `--name=`     | Module name used for the symlink (default: repo name or path basename) |
| `--commands=` | Relative path to commands directory within the repo/directory          |
| `--agents=`   | Relative path to agents directory within the repo/directory            |
| `--skills=`   | Relative path to skills directory within the repo/directory            |
| `--plugins=`  | Relative path to plugins directory within the repo/directory           |
| `--scripts=`  | Relative path to scripts directory within the repo/directory           |

When path flags are omitted, Telamon auto-detects `./commands`, `./agents`, `./skills`, `./scripts`, and `./plugins` in the cloned repo or local directory and wires any that exist.

#### Examples

```bash
# Add a remote module — name defaults to 'agent-skills'
telamon module add https://github.com/addyosmani/agent-skills.git

# Add with a custom name — symlinks will be .opencode/skills/addy, etc.
telamon module add https://github.com/addyosmani/agent-skills.git --name=addy

# Add with custom paths — skills live at the repo root
telamon module add https://github.com/org/repo.git --skills=. --agents=./my-agents

# Add a local directory (absolute path)
telamon module add /home/user/my-skills

# Add a local directory (relative path — resolved to absolute automatically)
telamon module add ./my-skills

# Add a local directory with a custom name
telamon module add /home/user/my-skills --name=custom

# Remove by name
telamon module remove agent-skills
```

Module configuration is stored in `.telamon.jsonc` under the `"modules"` key. The module name is the JSONC key:

```jsonc
{
  "modules": {
    "addyosmani": {
      "url": "https://github.com/addyosmani/agent-skills.git",
      "paths": { "agents": "agents", "skills": "skills" },
      "builtin": true
    },
    "my-skills": {
      "local_path": "/home/user/my-skills",
      "paths": { "skills": "./skills" }
    }
  }
}
```

Remote modules use a `"url"` field; local modules use a `"local_path"` field. A module entry will never have both. The `addyosmani` module is built-in and cannot be removed.

---

## Under the hood: make targets

The `telamon` CLI is a thin wrapper around `make` targets. When running from the Telamon directory, you can use `make` directly:

| Target                   | Description                                        |
|--------------------------|----------------------------------------------------|
| `make install`           | Full installation (first-time setup or reinstall)  |
| `make up`                | Boot services (no installation)                    |
| `make down`              | Stop Docker services                               |
| `make restart`           | Stop then start                                    |
| `make status`            | Quick installation status                          |
| `make doctor`            | Comprehensive health check                         |
| `make update`            | Upgrade all tools + install any missing            |
| `make init PROJ=<path>`  | Initialise a project                               |
| `make reset PROJ=<path>` | Remove project wiring, keep storage                |
| `make purge PROJ=<path>` | Remove wiring and storage                          |
| `make uninstall`         | Completely remove Telamon                          |
| `make test`              | Run the full test suite                            |

> `make init`, `make reset`, and `make purge` require the `PROJ=` argument. Use the `telamon` CLI for the default-to-cwd convenience.

---

## CLI installation

The `telamon` CLI is installed automatically as part of `make install`. It creates:

- **Symlink**: `~/.local/bin/telamon` → `<telamon-root>/bin/telamon`
- **Linux menu entry**: `~/.local/share/applications/telamon.desktop`
- **macOS app**: `~/Applications/Telamon.app`

The CLI resolves its own symlink chain to find the Telamon root, so it works from any location.
