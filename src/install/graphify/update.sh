#!/usr/bin/env bash
# Update graphify via uv.
# Exit codes: 0=success  1=failed  2=not-installed (skipped)

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "Graphify"

if ! command -v graphify &>/dev/null; then
  echo -e "  ${TEXT_DIM}–  graphify (not installed — skipping)${TEXT_CLEAR}"
  exit 2
fi

step "Upgrading graphify via uv..."
uv tool upgrade graphifyy 2>/dev/null \
  && log "graphify → $(graphify --version 2>/dev/null || echo 'updated')" \
  || { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  graphify upgrade failed — try: uv tool upgrade graphifyy"; exit 1; }
