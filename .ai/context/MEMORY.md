# MEMORY

Reusable decisions and discoveries across sessions. Add new entries at the top of each section.

---

## Renaming / Refactoring

### Grep sweeps miss files not read in the current session
**Date**: 2026-04-16
During the adk → telamon rename, `src/agents/*.md` and `src/commands/*.md` were missed in the final verification sweep because the grep pattern used `rtk grep` with a filter that excluded results containing "telamon" — but those files had *both* `adk` and `telamon` references, so they passed the filter silently. Always use a raw `grep -ri 'adk'` without exclusion filters for final verification, then manually triage the results.

### `src/agents/` and `src/commands/` contain hardcoded vault paths
**Date**: 2026-04-16
All agent role files (`src/agents/*.md`) and command files (`src/commands/*.md`) contain hardcoded `.ai/<project-name>/memory/` paths for scratch files and brain notes. When renaming the project, these files must be included in the rename sweep — they are easy to miss because they don't contain shell variables or config keys.

### Rename scope: runtime artifacts vs source files
**Date**: 2026-04-16
During the adk → telamon rename, the following were intentionally NOT changed:
- `.ai/adk/` — runtime directory (gitignored); recreated by `make init`
- `.ai/adk.ini` — runtime config (gitignored)
- `storage/graphify/`, `storage/obsidian/` — generated/cache data
- `tmp/` — gitignored test artifacts
- `.ai/issues/` — historical issue notes (runtime, gitignored)
- `no-vcs` files — per bootstrap rules, never touched
Only tracked source files under `src/`, `bin/`, `test/`, `Makefile`, `docker-compose.yml`, `storage/opencode.jsonc`, and `.ai/context/` were renamed.

---

## Obsidian MCP

### Obsidian REST API binds to `127.0.0.1` only — Docker bridge can't reach it
**Date**: 2026-04-16
The Obsidian Local REST API plugin listens on `127.0.0.1:27124` (loopback only), not `0.0.0.0`. Docker containers on the default bridge network reach the host via `172.17.0.1` (Docker bridge gateway), so connection is refused. On Linux, the fix is `--network host` in the `docker run` command so the container shares the host's network namespace and can reach `127.0.0.1` directly. On macOS, Docker Desktop transparently maps `host.docker.internal` to the host loopback, so the default bridge works fine.

### Obsidian MCP Docker command is OS-dependent
**Date**: 2026-04-16
`src/install/obsidian/install.sh` now emits different MCP configs per OS:
- **Linux**: `--network host` + `https://127.0.0.1:27124`
- **macOS**: default bridge + `https://host.docker.internal:27124`
The `opencode.jsonc` is written at install time and is OS-specific.

### `obsidian-mcp` Docker service removed from compose
**Date**: 2026-04-12
The always-on `obsidian-mcp` compose service was removed because it crashes at startup when Obsidian is not running (tests the API URL on boot, exits 1 if unreachable). The MCP is registered in `opencode.jsonc` as an on-demand `docker run` command instead — no persistent service needed.

---

## QMD

### QMD skill upstream URL is `tobi/qmd`, not `tobi/obsidian-mind`
**Date**: 2026-04-16
The QMD skill SKILL.md lives at `https://raw.githubusercontent.com/tobi/qmd/main/skills/qmd/SKILL.md`. The old URL referencing `tobi/obsidian-mind` was a 404 — that repo doesn't exist.

### QMD index path is controlled via `XDG_CACHE_HOME` only
**Date**: 2026-04-15
QMD has no `--db-path` flag or `QMD_HOME` env var. The only way to redirect its index (and model cache) away from `~/.cache/qmd/` is `XDG_CACHE_HOME`. Setting it to `${TELAMON_ROOT}/storage` puts both `storage/qmd/index.sqlite` and `storage/qmd/models/` under Telamon's storage tree (all gitignored by `storage/*`).

### `XDG_CACHE_HOME` for QMD must be set in four places
**Date**: 2026-04-15
Because `XDG_CACHE_HOME` is a global variable (affects all XDG-compliant apps), it must NOT be exported globally. Instead set it in every context where `qmd` runs:
1. **Telamon scripts** (`init-project.sh`, `update.sh`): `export XDG_CACHE_HOME="${TELAMON_ROOT}/storage"` at the top of the qmd section
2. **MCP server** (`opencode.jsonc`): `"environment": { "XDG_CACHE_HOME": "{file:.ai/telamon/secrets/qmd-cache-home}" }`
3. **Secrets file** (`storage/secrets/qmd-cache-home`): written by `install.sh` with the absolute Telamon storage path; referenced by opencode.jsonc
4. **Shell RC** (`~/.bashrc` / `~/.zshrc`): `qmd() { XDG_CACHE_HOME="<path>" command qmd "$@"; }` wrapper function written by `write-env.sh`

### Shell function wrapper pattern for env-scoped CLI tools
**Date**: 2026-04-15
When a CLI tool needs an env var set on every invocation but setting it globally would affect other tools, use a shell function wrapper:
```bash
qmd() { XDG_CACHE_HOME="/absolute/path" command qmd "$@"; }
```
The `command` builtin bypasses the function and calls the real binary, preventing infinite recursion. This pattern is idempotent when written with a marker comment and refreshed in-place by the installer.

### `{file:...}` in opencode.jsonc can inject any value, not just API keys
**Date**: 2026-04-15
The `{file:.ai/telamon/secrets/<name>}` pattern in opencode.jsonc MCP `environment` blocks reads the file content and injects it as the env var value. This works for any string — not just secrets. Used to inject the absolute Telamon storage path (`storage/secrets/qmd-cache-home`) as `XDG_CACHE_HOME` for the `qmd mcp` server.

### QMD collections: one per vault section, not one big collection
**Date**: 2026-04-15
Register separate QMD collections per vault section (`<project>-brain`, `<project>-work`, `<project>-reference`, `<project>-thinking`) rather than one `vault` collection. This lets agents query a specific area without noise from unrelated content. The `bootstrap/` folder is intentionally excluded — it is already loaded via AGENTS.md and does not benefit from semantic search.

---

## Shell / Bash

### `docker ps | grep` fails in pipefail subshells
**Date**: 2026-04-12
`docker ps | grep -q "container-name"` can silently fail in `set -euo pipefail` subshells when `docker ps` output has very long lines that get truncated by the pipe buffer.
**Fix**: always use `docker ps --format '{{.Names}}' | grep -q "^container-name$"` for exact name matching.

### Makefile evals shell expressions at parse time
**Date**: 2026-04-12
Lines like `IS_DOCKER := $(shell ./scripts/is-in-docker.sh)` are evaluated when `make` parses the Makefile, not when a target runs. A missing script causes an error on every `make` invocation, even for unrelated targets. Keep such helper scripts in version control even if trivial.

---

## Ogham

### `ogham health` fails with `SUPABASE_URL is required` after template fix
**Date**: 2026-04-12
If `~/.config/ogham/config.toml` was written with `DATABASE_BACKEND = "supabase"` (from a stale run before the template was corrected), `ogham health` fails validation even though Postgres is running fine. Self-heals when `make up` re-runs `ogham/install.sh` and overwrites the config. Not a code bug — a one-time machine-state issue.

### `ogham/config.toml.tmpl` must use `backend = "postgres"`
**Date**: 2026-04-12
The ogham installer template must set `[database] backend = "postgres"`. Using `"supabase"` requires a separate `SUPABASE_URL` env var and will break `ogham health` even with Postgres running.

---

## make / Makefile

### `docker compose up` must precede `run.sh` in `make up`
**Date**: 2026-04-12
The installer (`src/install/run.sh`) runs health checks (e.g. `ogham health`) that require the Postgres and Ollama containers to already be running. Always start `docker compose up -d` **before** calling `run.sh`.

---

## Installer / run.sh

### `--status` checks should use exact container name matching
**Date**: 2026-04-12
All container presence checks in the `--status` block must use `docker ps --format '{{.Names}}'` and anchor the grep pattern (`^name$`) to avoid false positives from partial name matches and false negatives from truncated output.

---

## opencode / JSONC config

### `storage/opencode.jsonc` contains `//` comments — never use `json.load`
**Date**: 2026-04-12
Any Python script that reads `storage/opencode.jsonc` must strip JSONC comments first. Use the inline `strip_jsonc_comments()` tokenizer (character-by-character parser handling strings, `//` line comments, `/* */` block comments). Both `opencode.upsert_mcp` and `opencode.set_mcp_env` in `functions/opencode.sh` already do this. Do not regress to `json.load`.

### `{file:path}` secret paths are relative to the project root
**Date**: 2026-04-12
opencode resolves `{file:...}` paths relative to the directory where `opencode.jsonc` lives. Since projects get a symlink `<proj>/opencode.jsonc → <telamon-root>/storage/opencode.jsonc`, the secret path in the config must be `storage/secrets/<name>` (relative to the project root, not the Telamon root).

---

## cass

### `cass index` is extremely slow — do not run in installer
**Date**: 2026-04-12
`cass index` on a real codebase takes 13+ minutes. It must not be called from `install.sh`. It runs lazily on first `cass search`. Remove any `cass index` call from the installer.

---

## Storage layout

### All Telamon output dirs live under `storage/`
**Date**: 2026-04-12
All runtime data, secrets, state, and cache must be under `storage/` in the Telamon root:
- `storage/pgdata/` — Postgres data volume
- `storage/ollama/` — Ollama model cache
- `storage/secrets/` — one plain-text file per secret (git-ignored)
- `storage/state/` — installer state (`setup-inputs`, `.setup-state`)
- `storage/opencode.jsonc` — shared opencode config (tracked in git)
Legacy root-level `pgdata/` and `ollama/` dirs are obsolete.

### `.gitignore` pattern for `storage/`
**Date**: 2026-04-12
Correct pattern:
```
storage/*
!storage/.gitkeep
!storage/opencode.jsonc
```
`storage/secrets/` does **not** need a separate exclusion line because `storage/*` already ignores everything; the `!` exceptions whitelist only what should be tracked.
