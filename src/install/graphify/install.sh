#!/usr/bin/env bash
# Install graphify (codebase knowledge graph tool) via uv.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
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
