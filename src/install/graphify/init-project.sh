#!/usr/bin/env bash
# Set up Graphify in the current project: install OpenCode plugin and git hooks.
#
# The graphify skill is shipped as a static file in src/skills/graphify/SKILL.md
# and is made available to projects via the .opencode/skills/adk symlink created
# by `make init`. No download or copying is needed.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "Graphify"

if command -v graphify &>/dev/null; then
  step "Installing graphify OpenCode integration..."
  graphify opencode install 2>/dev/null || true

  step "Installing graphify git hooks..."
  graphify hook install 2>/dev/null || true

  log "Graphify integrated (OpenCode plugin + git hooks)"
  info "Run /graphify inside OpenCode (or 'graphify .') to build the initial graph."
else
  warn "graphify not found — skipping project setup"
fi
