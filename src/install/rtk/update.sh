#!/usr/bin/env bash
# Update RTK via Homebrew and refresh the global OpenCode plugin.
# Exit codes: 0=success  1=failed  2=not-installed (skipped)

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ADK_ROOT="${ADK_ROOT:-$(cd "${INSTALL_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "RTK"

if ! command -v rtk &>/dev/null; then
  echo -e "  ${TEXT_DIM}–  rtk (not installed — skipping)${TEXT_CLEAR}"
  exit 2
fi

step "Upgrading RTK via Homebrew..."
# brew upgrade exits non-zero when package is already at latest; treat as success.
brew upgrade rtk-ai/tap/rtk 2>/dev/null \
  || brew upgrade rtk 2>/dev/null \
  || true
log "rtk → $(rtk --version 2>/dev/null || echo 'updated')"

step "Refreshing RTK OpenCode plugin..."
rtk init -g --opencode --auto-patch 2>/dev/null \
  && log "RTK OpenCode plugin refreshed" \
  || warn "RTK init failed — run 'rtk init -g --opencode' manually"

# Copy refreshed plugin into the ADK plugin source tree
RTK_GLOBAL_PLUGIN="${HOME}/.config/opencode/plugins/rtk.ts"
RTK_ADK_PLUGIN="${ADK_ROOT}/src/plugins/rtk.ts"
if [[ -f "${RTK_GLOBAL_PLUGIN}" ]]; then
  cp "${RTK_GLOBAL_PLUGIN}" "${RTK_ADK_PLUGIN}"
  log "Updated src/plugins/rtk.ts from global plugin"
else
  warn "RTK global plugin not found at ${RTK_GLOBAL_PLUGIN} — skipping copy"
fi
