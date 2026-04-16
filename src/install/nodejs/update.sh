#!/usr/bin/env bash
# Update npm global packages.
# Exit codes: 0=success  1=failed  2=not-installed (skipped)

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "Node.js tools"

if ! command -v npm &>/dev/null; then
  echo -e "  ${TEXT_DIM}–  npm (not installed — skipping)${TEXT_CLEAR}"
  exit 2
fi

step "Updating npm global packages..."
npm update -g --quiet 2>/dev/null \
  && log "npm global packages updated" \
  || { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  npm global update failed"; exit 1; }
