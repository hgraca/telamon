#!/usr/bin/env bash
# Install opencode (AI coding agent) and write <adk-root>/storage/opencode.jsonc
# from the template if it does not already exist.
#
# The storage/opencode.jsonc file is the shared config for all projects using
# this ADK. On `make init`, each project gets a symlink pointing to it.
# Each tool's install script adds its own MCP block via opencode.upsert_mcp.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADK_ROOT="$(cd "${INSTALL_PATH}/../.." && pwd)"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

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
STORAGE_CONFIG="${ADK_ROOT}/storage/opencode.jsonc"

if [[ -f "${STORAGE_CONFIG}" ]]; then
  skip "storage/opencode.jsonc (already exists)"
else
  cp "${SCRIPT_DIR}/opencode.dist.jsonc" "${STORAGE_CONFIG}"
  log "storage/opencode.jsonc created → ${STORAGE_CONFIG}"
  info "Tool install scripts will register their MCP servers into this file."
fi

# Export for tool install scripts that patch opencode.json
export OPENCODE_CONFIG_FILE="${STORAGE_CONFIG}"
