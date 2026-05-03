#!/usr/bin/env bash
# Update npm global packages.
# Exit codes: 0=success  1=failed  2=not-installed (skipped)

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "Node.js tools"

if ! command -v npm &>/dev/null; then
  echo -e "  ${TEXT_DIM}–  npm (not installed — skipping)${TEXT_CLEAR}"
  exit 2
fi

# Clean stale npm temp dirs from previous interrupted installs (ENOTEMPTY fix)
# These appear at top level (.opencode-ai-XXXX) and inside scoped dirs (@tobilu/.qmd-XXXX)
NPM_GLOBAL_PREFIX="$(npm prefix -g 2>/dev/null || echo "")"
if [[ -n "${NPM_GLOBAL_PREFIX}" && -d "${NPM_GLOBAL_PREFIX}/lib/node_modules" ]]; then
  find "${NPM_GLOBAL_PREFIX}/lib/node_modules" -maxdepth 2 -name ".*" -type d -exec rm -rf {} + 2>/dev/null || true
fi

step "Updating npm global packages..."
_npm_ok=0
_npm_out="$(npm update -g 2>&1)" && _npm_ok=1

if [[ "${_npm_ok}" -eq 0 ]]; then
  # Self-heal: clean stale temp dirs and retry
  find "${NPM_GLOBAL_PREFIX}/lib/node_modules" -maxdepth 2 -name ".*" -type d -exec rm -rf {} + 2>/dev/null || true
  _npm_out="$(npm update -g 2>&1)" && _npm_ok=1
fi

if [[ "${_npm_ok}" -eq 1 ]]; then
  log "npm global packages updated"
else
  warn "npm global update failed (non-fatal):"
  echo "${_npm_out}" | grep -i "error" | head -5 | sed 's/^/       /'
fi
