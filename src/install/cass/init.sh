#!/usr/bin/env bash
# Build the initial cass session-history index.
# Idempotent: skipped if state flag 'cass_indexed' is set.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "cass — Index Agent Sessions"

if state.done "cass_indexed"; then
  skip "cass initial index"; exit 0
fi

if command -v cass &>/dev/null; then
  step "Building initial cass index..."
  cass index 2>/dev/null || true
  state.mark "cass_indexed"
  log "cass index built"
else
  warn "cass not found — skipping index"
fi
