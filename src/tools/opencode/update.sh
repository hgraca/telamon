#!/usr/bin/env bash
# Update opencode via npm.
# Exit codes: 0=success  1=failed  2=not-installed (skipped)

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "opencode"

if ! command -v opencode &>/dev/null; then
  echo -e "  ${TEXT_DIM}–  opencode (not installed — skipping)${TEXT_CLEAR}"
  exit 2
fi

step "Upgrading opencode via npm..."
npm install -g opencode-ai --quiet 2>/dev/null \
  && log "opencode → $(opencode --version 2>/dev/null || echo 'updated')" \
  || { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  opencode upgrade failed — try: npm install -g opencode-ai"; exit 1; }

# Apply upstream patches (if configured)
bash "${TOOLS_PATH}/opencode/apply-patches.sh" || true
