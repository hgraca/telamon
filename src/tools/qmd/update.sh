#!/usr/bin/env bash
# Update QMD and refresh the vault index.
# Exit codes: 0=success  1=failed  2=not-installed (skipped)

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TELAMON_ROOT="${TELAMON_ROOT:-$(cd "${TOOLS_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "QMD (semantic vault search)"

if ! command -v qmd &>/dev/null; then
  echo -e "  ${TEXT_DIM}–  qmd (not installed — skipping)${TEXT_CLEAR}"
  exit 2
fi

# Redirect QMD cache to Telamon storage (matches install/qmd/init.sh)
export XDG_CACHE_HOME="${TELAMON_ROOT}/storage"
mkdir -p "${TELAMON_ROOT}/storage/qmd"

step "Upgrading QMD via npm..."
_npm_out="$(npm install -g @tobilu/qmd 2>&1)" && _npm_ok=1 || _npm_ok=0

if [[ "${_npm_ok}" -eq 1 ]]; then
  log "qmd → $(XDG_CACHE_HOME="${TELAMON_ROOT}/storage" qmd --version 2>/dev/null || echo 'updated')"
else
  warn "QMD upgrade failed (non-fatal):"
  echo "${_npm_out}" | grep -i "error" | head -5 | sed 's/^/       /'
fi

step "Refreshing QMD vault index..."
if qmd update 2>/dev/null && qmd embed 2>/dev/null; then
  log "QMD vault index refreshed"
else
  warn "QMD re-index did not complete cleanly — run manually: XDG_CACHE_HOME=${TELAMON_ROOT}/storage qmd update && qmd embed"
fi
