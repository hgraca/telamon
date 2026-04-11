#!/usr/bin/env bash
# Install ogham-mcp via uv.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "Ogham MCP"

if ! command -v ogham &>/dev/null; then
  step "Installing ogham-mcp via uv..."
  uv tool install ogham-mcp
  export PATH="$HOME/.local/bin:$PATH"
  log "Ogham installed"
else
  skip "Ogham ($(ogham --version 2>/dev/null || echo 'installed'))"
fi
