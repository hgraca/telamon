---
layout: page
title: Opencode Patches
description: Automatically apply upstream PR patches to opencode.
nav_section: docs
---

## What it does

Allows you to run a custom-built opencode binary with patches from upstream PRs that haven't been merged yet. Useful for cherry-picking fixes or features before official release.

The feature has two parts:
1. **Build script** (`src/tools/opencode/apply-patches.sh`) — clones the opencode source, applies patches from configured PR URLs, builds from source with Bun, and replaces the installed binary.
2. **Auto-detection plugin** (`src/plugins/opencode-patches.js`) — detects when opencode auto-updates (binary hash changes) and re-applies patches in the background.

## Configuration

Add PR URLs to `.telamon.jsonc` (the global Telamon config at the repo root):

```jsonc
{
  "opencode_patches": [
    "https://github.com/anomalyco/opencode/pull/18559"
  ]
}
```

When the array is empty (default), the feature is inactive — no source clone, no build.

## How it works

### On `make update` / `make install`

1. After opencode is updated via npm, `apply-patches.sh` runs
2. Reads PR URLs from `.telamon.jsonc`
3. Clones (or fetches) the opencode source to `storage/opencode-src/`
4. Checks out the tag matching the installed version (falls back to `dev` branch)
5. Downloads each PR's `.patch` file from GitHub and applies it with `git apply`
6. Builds opencode from source using Bun
7. Replaces the binary at `~/.opencode/bin/opencode`
8. Saves state (version, binary hash) to `storage/opencode-patch-state.json`

### Auto-update detection (plugin)

On the first tool call of each session:
- Compares the stored binary hash with the current binary
- If mismatch detected (opencode auto-updated), spawns the rebuild in the background
- Prints a message suggesting restart once complete

## Prerequisites

- **Bun** must be installed (required to build opencode from source)
- Internet access (to clone repo and download patches)

## Troubleshooting

- If the version tag doesn't exist, the script falls back to the `dev` branch
- Individual patch failures are logged as warnings but don't abort the build
- If the build fails, the original binary remains untouched
- State file at `storage/opencode-patch-state.json` can be deleted to force a re-patch
