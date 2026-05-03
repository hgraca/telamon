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

# Check if update is needed by comparing local version with latest repo tag
CURRENT_VERSION="$(opencode --version 2>/dev/null || echo "0.0.0")"
LATEST_VERSION="$(git ls-remote --tags https://github.com/anomalyco/opencode.git 'refs/tags/v[0-9]*' 2>/dev/null \
  | sed 's|.*refs/tags/v||' | sort -V -r | head -1 || echo "")"

if [[ -n "${LATEST_VERSION}" && "${CURRENT_VERSION}" == "${LATEST_VERSION}" ]]; then
  log "opencode v${CURRENT_VERSION} (already latest)"
else
  step "Upgrading opencode via npm..."
  _npm_out="$(npm install -g opencode-ai 2>&1)" && _npm_ok=1 || _npm_ok=0

  if [[ "${_npm_ok}" -eq 1 ]]; then
    log "opencode → $(opencode --version 2>/dev/null || echo 'updated')"
  else
    warn "npm upgrade failed (non-fatal):"
    echo "${_npm_out}" | grep -i "error" | head -5 | sed 's/^/       /'
  fi
fi

# Apply upstream patches (if configured)
bash "${TOOLS_PATH}/opencode/apply-patches.sh" || true
