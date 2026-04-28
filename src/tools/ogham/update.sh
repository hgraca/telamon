#!/usr/bin/env bash
# Update ogham-mcp via uv.
# Exit codes: 0=success  1=failed  2=not-installed (skipped)

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "Ogham MCP"

if ! command -v ogham &>/dev/null; then
  echo -e "  ${TEXT_DIM}–  ogham (not installed — skipping)${TEXT_CLEAR}"
  exit 2
fi

step "Upgrading ogham-mcp via uv..."
uv tool upgrade ogham-mcp 2>/dev/null \
  && log "ogham → $(ogham --version 2>/dev/null || echo 'updated')" \
  || { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  ogham upgrade failed — try: uv tool upgrade ogham-mcp"; exit 1; }

# Ensure prefab-ui stays present after upgrades (not an ogham extras group)
uv tool install "ogham-mcp[postgres,rerank]" --with prefab-ui 2>/dev/null \
  || warn "Could not re-install prefab-ui after upgrade — dashboard tools may fail"
