#!/usr/bin/env bash
# Install graphify (codebase knowledge graph tool) via uv,
# and register its OpenCode plugin in storage/opencode.jsonc.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TELAMON_ROOT="${TELAMON_ROOT:-$(cd "${INSTALL_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "Graphify"

if ! command -v graphify &>/dev/null; then
  step "Installing graphifyy via uv..."
  uv tool install graphifyy
  export PATH="$HOME/.local/bin:$PATH"
  log "Graphify installed"

  # ── Resolve and store Python interpreter for MCP server ───────────────────────
  GRAPHIFY_PYTHON="$(uv tool run --from graphifyy python3 -c 'import sys; print(sys.executable)')"
  echo -n "${GRAPHIFY_PYTHON}" > "${TELAMON_ROOT}/storage/secrets/graphify-python"
  log "Stored graphify Python path: ${GRAPHIFY_PYTHON}"
else
  skip "Graphify ($(graphify --version 2>/dev/null || echo 'installed'))"

  # ── Resolve and store Python interpreter for MCP server ───────────────────────
  GRAPHIFY_PYTHON="$(uv tool run --from graphifyy python3 -c 'import sys; print(sys.executable)')"
  echo -n "${GRAPHIFY_PYTHON}" > "${TELAMON_ROOT}/storage/secrets/graphify-python"
  log "Stored graphify Python path: ${GRAPHIFY_PYTHON}"
fi

# ── Store Telamon root for MCP environment injection ─────────────────────────
echo -n "${TELAMON_ROOT}" > "${TELAMON_ROOT}/storage/secrets/telamon-root"
log "Stored TELAMON_ROOT: ${TELAMON_ROOT}"

# ── Register OpenCode plugin in storage/opencode.jsonc ────────────────────────
# The plugin JS lives in src/plugins/graphify.js (Telamon source of truth).
# Projects receive it via the .opencode/plugins/telamon symlink created by `make init`.
opencode.upsert_plugin ".opencode/plugins/telamon/graphify.js"

# ── Register MCP server ──────────────────────────────────────────────────────
opencode.upsert_mcp "graphify" '{
  "type": "local",
  "command": ["bash", ".opencode/graphify-serve.sh", "graphify-out/graph.json"],
  "environment": {
    "TELAMON_ROOT": "{file:storage/secrets/telamon-root}"
  },
  "enabled": true
}'
