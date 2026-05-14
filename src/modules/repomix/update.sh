#!/usr/bin/env bash
# Update repomix CLI via npm.
# Exit codes: 0=success  1=failed  2=not-installed (skipped)

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "Repomix"

if ! command -v repomix &>/dev/null; then
  echo -e "  ${TEXT_DIM}–  repomix (not installed — skipping)${TEXT_CLEAR}"
  exit 2
fi

CURRENT_VERSION="$(repomix --version 2>/dev/null || echo "0.0.0")"
LATEST_VERSION="$(npm view repomix version 2>/dev/null || echo "")"

if [[ -n "${LATEST_VERSION}" && "${CURRENT_VERSION}" == "${LATEST_VERSION}" ]]; then
  log "repomix v${CURRENT_VERSION} (already latest)"
else
  step "Upgrading repomix via npm..."
  npm install -g repomix 2>/dev/null \
    && log "repomix → $(repomix --version 2>/dev/null || echo 'updated')" \
    || { warn "repomix upgrade failed — try: npm install -g repomix"; exit 1; }
fi