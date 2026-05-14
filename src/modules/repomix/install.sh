#!/usr/bin/env bash
# Install repomix CLI globally via npm.
# The CLI replaces the previous MCP server — agents use `repomix pack`, `repomix grep`, etc.
# directly via bash tool.

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "Repomix"

if command -v repomix &>/dev/null; then
  skip "repomix ($(repomix --version 2>/dev/null || echo 'installed'))"
else
  step "Installing repomix via npm..."
  npm install -g repomix
  log "repomix installed ($(repomix --version 2>/dev/null))"
fi