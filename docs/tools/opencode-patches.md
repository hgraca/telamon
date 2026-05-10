---
layout: page
title: Opencode Patches
description: On-demand patched opencode build via the /patch-opencode slash command.
nav_section: docs
---

## What it does

Lets you run a custom-built opencode binary with patches from upstream PRs that have not been merged yet. Useful for cherry-picking fixes or features before they ship.

The build is **never triggered automatically** — you invoke it explicitly from inside an opencode session with `/patch-opencode`.

## Configuration

List PR URLs in `.telamon.jsonc` at the repo root:

```jsonc
{
  "opencode_patches": [
    "https://github.com/anomalyco/opencode/pull/18559",
    "https://github.com/anomalyco/opencode/pull/14772"
  ]
}
```

When the array is empty (the default), the feature is inactive.

## Usage

From inside any opencode session:

```
/patch-opencode               # patch on top of the latest released tag
/patch-opencode latest        # same as above
/patch-opencode dev           # patch on top of upstream dev branch HEAD
/patch-opencode 1.14.44       # patch on top of v1.14.44
```

The patched binary is **always stamped as version `666.0.0`** so you can tell at a glance with `opencode --version` that you are running the patched build (and not a vanilla npm install).

`make update` detects this stamp and skips the npm upgrade so a vanilla binary never silently replaces your patched one. To go back to vanilla, delete `~/.opencode/bin/opencode` and run `make update`, or restore one of the backups under `storage/opencode-backups/`.

## How it works

1. Read `opencode_patches` from `.telamon.jsonc`
2. Clone (or fetch) the opencode source into `storage/opencode-src/`
3. Hard-reset the working tree to the requested ref
4. Apply each PR sequentially:
   - **Clean apply** → continue
   - **3-way merge succeeds** → continue
   - **Conflict** → exit code 3, write `storage/opencode-patch-conflict.json`, hand off to the LLM (the agent reads the file, resolves the conflict markers, then re-runs the script with `--resume`)
5. Save the combined diff to `storage/opencode-src/combined.patch` (record of what got applied)
6. Build for the current OS only via `packages/opencode/script/build.ts --single`, with `OPENCODE_VERSION=666.0.0` exported so the binary self-reports as patched
7. Smoke test: `<built-binary> --version` must contain `666.0.0`
8. Backup the current binary to `storage/opencode-backups/opencode-v<old-version>-<timestamp>`
9. Atomic `mv` replacement of `~/.opencode/bin/opencode`
10. Verify the installed binary still runs (rolls back to the backup on failure)
11. Save state to `storage/opencode-patch-state.json`

## Files

| Path                                          | Purpose                                                |
|-----------------------------------------------|--------------------------------------------------------|
| `src/commands/patch-opencode/patch-opencode.sh` | The build script (does all the heavy lifting)        |
| `src/commands/patch-opencode/patch-opencode.md` | The `/patch-opencode` slash command definition       |
| `storage/opencode-src/`                       | Opencode source clone (kept for fast incremental fetches) |
| `storage/opencode-src/combined.patch`         | Diff of all applied PRs vs. the base ref               |
| `storage/opencode-backups/`                   | Previous binaries, ready for manual rollback           |
| `storage/opencode-patch-state.json`           | Last successful build (target ref, applied PRs, SHA)   |
| `storage/opencode-patch-conflict.json`        | Present only while a merge conflict is being resolved  |

## Prerequisites

- **Bun** ≥ `bun_version` from `.telamon.jsonc` (auto-installed/upgraded by the script if missing)
- Internet access (clone repo, download patches)

## Troubleshooting

- **Conflict on every run** — a PR is too stale to apply automatically. Either remove it from the list, or resolve the conflict once and let the agent re-run with `--resume`.
- **`make update` overwrote my patched binary** — should not happen because `update.sh` detects the `666.0.0` stamp. If it did, restore from `storage/opencode-backups/` and re-run `/patch-opencode`.
- **Need to revert** — `cp storage/opencode-backups/opencode-v<version>-<timestamp> ~/.opencode/bin/opencode`.
