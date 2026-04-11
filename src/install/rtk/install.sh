#!/usr/bin/env bash
# Install RTK (token compression proxy) via Homebrew tap and wire up OpenCode plugin.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "RTK (token compression)"

if ! command -v rtk &>/dev/null; then
  step "Installing RTK via Homebrew..."
  brew tap rtk-ai/tap 2>/dev/null || true
  brew install rtk-ai/tap/rtk
  log "RTK installed"
else
  skip "RTK ($(rtk --version 2>/dev/null || echo 'installed'))"
fi

# Wire up the OpenCode plugin (idempotent — rtk init is safe to re-run)
step "Installing RTK OpenCode plugin..."
rtk init -g --opencode --auto-patch 2>/dev/null \
  && log "RTK OpenCode plugin installed (bash commands auto-compressed)" \
  || warn "RTK init failed — run 'rtk init -g --opencode' manually after setup"
