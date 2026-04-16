#!/usr/bin/env bash
# Update QMD and refresh the vault index.
# Exit codes: 0=success  1=failed  2=not-installed (skipped)

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ADK_ROOT="${ADK_ROOT:-$(cd "${INSTALL_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "QMD (semantic vault search)"

if ! command -v qmd &>/dev/null; then
  echo -e "  ${TEXT_DIM}–  qmd (not installed — skipping)${TEXT_CLEAR}"
  exit 2
fi

# Redirect QMD cache to ADK storage (matches install/qmd/init.sh)
export XDG_CACHE_HOME="${ADK_ROOT}/storage"
mkdir -p "${ADK_ROOT}/storage/qmd"

_failed=0

step "Upgrading QMD via npm..."
npm install -g @tobilu/qmd --quiet 2>/dev/null \
  && log "qmd → $(XDG_CACHE_HOME="${ADK_ROOT}/storage" qmd --version 2>/dev/null || echo 'updated')" \
  || { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  QMD upgrade failed — try: npm install -g @tobilu/qmd"; _failed=1; }

step "Refreshing QMD vault index..."
if qmd update 2>/dev/null && qmd embed 2>/dev/null; then
  log "QMD vault index refreshed"
else
  warn "QMD re-index did not complete cleanly — run manually: XDG_CACHE_HOME=${ADK_ROOT}/storage qmd update && qmd embed"
fi

[[ "${_failed}" -eq 0 ]] || exit 1
