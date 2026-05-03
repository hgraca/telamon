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
NPM_GLOBAL_PREFIX="$(npm prefix -g 2>/dev/null || echo "")"
if [[ -n "${NPM_GLOBAL_PREFIX}" ]]; then
  find "${NPM_GLOBAL_PREFIX}/lib/node_modules" -maxdepth 1 -name ".*" -type d -mmin +5 -exec rm -rf {} + 2>/dev/null || true
fi

step "Updating npm global packages..."
npm update -g --quiet 2>/dev/null \
  && log "npm global packages updated" \
  || warn "npm global update failed (non-fatal)"
