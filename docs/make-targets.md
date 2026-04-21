---
layout: page
title: Commands
description: All available telamon CLI commands and make targets.
nav_section: docs
---

## Global CLI

After running `make up` once, the `telamon` command is available system-wide from any directory.

| Command                   | Description                                                     |
|---------------------------|-----------------------------------------------------------------|
| `telamon up`              | Install host tools + start Docker services                      |
| `telamon down`            | Stop Docker services                                            |
| `telamon restart`         | `down` then `up`                                                |
| `telamon status`          | Quick installation status of all Telamon tools                  |
| `telamon doctor`          | Comprehensive health check (connectivity, config, secrets)      |
| `telamon update`          | Upgrade all Telamon-managed tools to their latest versions      |
| `telamon init [path]`     | Initialise a project to use Telamon (default: current directory)|
| `telamon reset [path]`    | Remove project wiring, keep storage data (default: current dir) |
| `telamon purge [path]`    | Remove project wiring **and** storage data (default: current dir)|
| `telamon uninstall`       | Completely remove Telamon from the system (destructive)         |
| `telamon help`            | Show usage help                                                 |

### Path handling

`init`, `reset`, and `purge` accept an optional path argument. If omitted, they operate on the current working directory. Relative paths are resolved against the caller's working directory, so these all work:

```bash
cd ~/my-project && telamon init          # initialises ~/my-project
telamon init ~/my-project                # same result, from anywhere
telamon init ../other-project            # relative path, resolved correctly
```

---

## Make targets

When running from the Telamon repository directory, `make` targets are the equivalent interface. The `telamon` CLI is a thin wrapper around these.

| Target                    | Description                                                     |
|---------------------------|-----------------------------------------------------------------|
| `make up`                 | Install host tools + start Docker services                      |
| `make down`               | Stop Docker services                                            |
| `make restart`            | `down` then `up`                                                |
| `make status`             | Quick installation status of all Telamon tools                  |
| `make doctor`             | Comprehensive health check (connectivity, config, secrets)      |
| `make update`             | Upgrade all Telamon-managed tools to their latest versions      |
| `make init PROJ=<path>`   | Initialise a project to use Telamon                             |
| `make reset PROJ=<path>`  | Remove project wiring, keep storage data                        |
| `make purge PROJ=<path>`  | Remove project wiring **and** storage data                      |
| `make uninstall`          | Completely remove Telamon from the system (destructive)         |
| `make test`               | Run the full test suite (make up + init dummy project + assert) |

> **Note:** `make init`, `make reset`, and `make purge` require the `PROJ=` argument — they do not default to the current directory. Use the `telamon` CLI for the default-to-cwd convenience.

---

## Installation

The `telamon` CLI is installed automatically as part of `make up`. It creates:

- **Symlink**: `~/.local/bin/telamon` → `<telamon-root>/bin/telamon`
- **Linux menu entry**: `~/.local/share/applications/telamon.desktop` — clicking it opens a terminal and runs `telamon up`
- **macOS app**: `~/Applications/Telamon.app` — clicking it opens Terminal and runs `telamon up`

The CLI resolves its own symlink chain to find the Telamon root directory, so it works from any location on the system.
