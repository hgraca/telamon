---
layout: page
title: Configuration
description: Settings, environment variables, and optional service activation.
nav_section: docs
---

## Global settings

The installer handles **everything** automatically. The `.env` file at `~/.telamon/.env` is used only for optional services (see below).

---

## Per-project settings

Each initialized project has a config file at `.ai/telamon/telamon.jsonc` (created by `telamon init`).
Edit this file directly, or run `telamon config` to update it interactively.

```jsonc
{
  "project_name": "my-app",
  "medium_model": "",
  "memory_owner": "telamon",
  "rtk_enabled": true,
  "caveman_enabled": true,
  "gpu_enabled": false,
  "docker_gpu_enabled": false,
  "agent_communication": {
    "enabled": true,
    "max_attempts": 2,
    "exempt_agents": ["repomix-agent", "qmd"]
  },
  "ogham_db": "telamon"
}
```

|  Key                                   | Default                            | Description                                                                                                                                                                                                |
| -------------------------------------- | ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|  `project_name`                        | Directory basename                 | Display name used in memory vaults and logs                                                                                                                                                                |
|  `medium_model`                        | *(empty — prompts on first use)*   | LLM model for batch operations like `recover-memories`. On first use, the CLI prompts with suggestions from the project's `model`/`small_model` in `opencode.jsonc` (e.g. Opus+Haiku → suggests Sonnet).   |
|  `memory_owner`                        | `telamon`                          | Where memory files live: `telamon` (files in Telamon storage, symlink in project) or `project` (files in project repo, symlink in Telamon storage).                                                        |
|  `rtk_enabled`                         | `true`                             | Enable [RTK](tools/rtk) output compression. Runs bash commands through RTK rewriting for token savings. Set to `false` to disable.                                                                         |
|  `caveman_enabled`                     | `true`                             | Enable [Caveman](tools/caveman) terse communication mode. Compressed responses that save tokens. Set to `false` to disable.                                                                                |
|  `gpu_enabled`                         | `false`                            | Enable GPU support for local models.                                                                                                                                                                       |
|  `docker_gpu_enabled`                  | `false`                            | Enable GPU passthrough inside Docker containers.                                                                                                                                                           |
|  `agent_communication.enabled`         | `true`                             | Enable the structured inter-agent delegation protocol.                                                                                                                                                     |
|  `agent_communication.max_attempts`    | `2`                                | Maximum retry attempts for delegated agent work before escalating.                                                                                                                                         |
|  `agent_communication.exempt_agents`   | `["repomix-agent", "qmd"]`         | Agents excluded from the delegation protocol.                                                                                                                                                              |
|  `ogham_db`                            | `telamon`                          | Ogham database name. Use `external` and set `OGHAM_DB_URL` for a separate database.                                                                                                                        |

`rtk_enabled` and `caveman_enabled` are **enabled by default** because they significantly reduce token usage.
Set to `false` in projects where you prefer verbose output or if RTK causes issues with specific command output.

Changes take effect on the next opencode session — no restart required for RTK (read at plugin init) or Caveman (read at bootstrap).

---

## Global settings (`.telamon.jsonc`)

The file `.telamon.jsonc` in the Telamon root directory contains global settings that apply to the Telamon installation itself (not per-project). Run `telamon config --global` to update it interactively.

```jsonc
{
  "modules": { ... },
  "opencode_patches": [],
  "bun_version": "^1.3.13",
  "skill": {
    "gather-context": {
      "context-cache": { "ttl": "7d" }
    }
  }
}
```

|  Key                                           | Default       | Description                                                                                                                  |
| ---------------------------------------------- | ------------- | ---------------------------------------------------------------------------------------------------------------------------- |
|  `modules`                                     | `{}`          | External modules (agent skills, commands, plugins) from git repos or local paths. See [CLI — module](cli.md#module).         |
|  `opencode_patches`                            | `[]`          | Array of GitHub PR URLs applied on demand by `/patch-opencode`. See [Opencode Patches](tools/opencode-patches) for details   |
|  `bun_version`                                 | `^1.3.13`     | Required Bun runtime version constraint (semver range). Used by install and update scripts.                                  |
|  `skill.gather-context.context-cache.ttl`      | `7d`          | Cache TTL for gather-context reports. Format: `Nd` (days), `Nh` (hours), `Nm` (minutes).                                     |

Patches are applied on demand via the `/patch-opencode` slash command — never automatically on `make install` or `make update`.

---

## Optional services

There are currently no optional services. All tools are installed and enabled by default.
