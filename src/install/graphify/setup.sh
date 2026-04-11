#!/usr/bin/env bash
# Set up Graphify in the current project: install OpenCode plugin, git hooks,
# and download the graphify skill for the global OpenCode skills directory.

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

# Install graphify skill for OpenCode
SKILL_DIR="$HOME/.config/opencode/skills/graphify"
if [[ -f "${SKILL_DIR}/SKILL.md" ]]; then
  skip "graphify skill"
else
  mkdir -p "${SKILL_DIR}"
  curl -fsSL \
    "https://raw.githubusercontent.com/safishamsi/graphify/v3/graphify/skill.md" \
    -o "${SKILL_DIR}/SKILL.md" 2>/dev/null \
    && log "Graphify skill installed → ${SKILL_DIR}/SKILL.md" \
    || warn "Could not download graphify skill — install manually later"
fi
