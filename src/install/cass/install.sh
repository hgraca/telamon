#!/usr/bin/env bash
# Install cass (agent session history search) via Homebrew tap.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "cass (agent session search)"

if ! command -v cass &>/dev/null; then
  step "Installing cass via Homebrew..."
  brew tap dicklesworthstone/tap 2>/dev/null || true
  brew install dicklesworthstone/tap/cass
  log "cass installed"
else
  skip "cass ($(cass --version 2>/dev/null || echo 'installed'))"
fi
