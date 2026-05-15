#!/usr/bin/env bash
# Install opencode (AI coding agent) and write <telamon-root>/storage/opencode.jsonc
# from the template if it does not already exist.
#
# The storage/opencode.jsonc file is the shared config for all projects using
# Telamon. On `make init`, each project gets a symlink pointing to it.
# Each tool's install script adds its own MCP block via opencode.upsert_mcp.

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TELAMON_ROOT="$(cd "${TOOLS_PATH}/../.." && pwd)"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

# ── Install binary ─────────────────────────────────────────────────────────────
header "opencode"

if ! command -v opencode &>/dev/null; then
  step "Installing opencode..."
  if command -v npm &>/dev/null; then
    npm install -g opencode-ai
    export PATH="$(npm root -g)/.bin:$PATH"
    log "opencode installed via npm"
  else
    error "Node.js / npm not found — cannot install opencode. Run nodejs/install.sh first."
  fi
else
  skip "opencode ($(opencode --version 2>/dev/null || echo 'installed'))"
fi

# ── Write shared config if missing ────────────────────────────────────────────
STORAGE_CONFIG="${TELAMON_ROOT}/storage/opencode.jsonc"

if [[ -f "${STORAGE_CONFIG}" ]]; then
  skip "storage/opencode.jsonc (already exists)"
else
  cp "${SCRIPT_DIR}/opencode.dist.jsonc" "${STORAGE_CONFIG}"
  log "storage/opencode.jsonc created → ${STORAGE_CONFIG}"
  info "Tool install scripts will register their MCP servers into this file."
fi

# Export for tool install scripts that patch opencode.json
export OPENCODE_CONFIG_FILE="${STORAGE_CONFIG}"

# ── Install @opencode-ai/plugin for custom tools ──────────────────────────────
# Custom tools under src/instructions/tools/<name>/<name>.ts import from
# @opencode-ai/plugin, which Bun resolves from the file's real path. Installing
# once at src/instructions/tools/node_modules/ covers every tool .ts under that
# tree. This is telamon-checkout-scoped — NOT per-project — so it lives here
# (and in opencode/update.sh) rather than in opencode/init.sh.
# See latent/gotchas.md "Opencode custom tools require flat layout AND
# co-located node_modules" (2026-05-10).
TOOLS_SRC="${TELAMON_ROOT}/src/instructions/tools"
if [[ -f "${TOOLS_SRC}/package.json" ]]; then
  if command -v bun &>/dev/null; then
    step "Installing custom-tool dependencies (@opencode-ai/plugin)..."
    if (cd "${TOOLS_SRC}" && bun install) >/dev/null 2>&1; then
      log "Custom-tool deps installed → ${TOOLS_SRC}/node_modules/"
    else
      warn "bun install failed in ${TOOLS_SRC} — custom tools will not load"
    fi
  else
    warn "bun not found — cannot install @opencode-ai/plugin; custom tools will not load. Install bun and re-run \`make install\`."
  fi
fi
