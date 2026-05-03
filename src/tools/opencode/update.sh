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
LATEST_VERSION="$(git ls-remote --tags --sort=-v:refname https://github.com/anomalyco/opencode.git 'refs/tags/v*' 2>/dev/null \
  | head -1 | sed 's|.*refs/tags/v||' || echo "")"

if [[ -n "${LATEST_VERSION}" && "${CURRENT_VERSION}" == "${LATEST_VERSION}" ]]; then
  log "opencode v${CURRENT_VERSION} (already latest)"
else
  step "Upgrading opencode via npm..."
  npm install -g opencode-ai --quiet 2>/dev/null \
    && log "opencode → $(opencode --version 2>/dev/null || echo 'updated')" \
    || warn "npm upgrade failed (non-fatal) — patches will still be applied"
fi

# Apply upstream patches (if configured)
bash "${TOOLS_PATH}/opencode/apply-patches.sh" || true
