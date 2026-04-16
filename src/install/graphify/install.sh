#!/usr/bin/env bash
# Install graphify (codebase knowledge graph tool) via uv,
# and register its OpenCode plugin in storage/opencode.jsonc.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "Graphify"

if ! command -v graphify &>/dev/null; then
  step "Installing graphifyy via uv..."
  uv tool install graphifyy
  export PATH="$HOME/.local/bin:$PATH"
  log "Graphify installed"
else
  skip "Graphify ($(graphify --version 2>/dev/null || echo 'installed'))"
fi

# ── Register OpenCode plugin in storage/opencode.jsonc ────────────────────────
# The plugin JS lives in src/plugins/graphify.js (Telamon source of truth).
# Projects receive it via the .opencode/plugins/telamon symlink created by `make init`.
opencode.upsert_plugin ".opencode/plugins/telamon/graphify.js"
