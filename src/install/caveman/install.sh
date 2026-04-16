#!/usr/bin/env bash
# Download the caveman skill (token-efficient communication mode) into
# src/skills/dev/caveman/ so it is available to all initialized projects
# via the .opencode/skills/adk symlink created by bin/init.sh.
#
# caveman has no binary — it is a skill-only tool.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ADK_ROOT="${ADK_ROOT:-$(cd "${INSTALL_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "caveman (token-efficient communication skill)"

SKILL_URL="https://raw.githubusercontent.com/JuliusBrussee/caveman/main/caveman/SKILL.md"
SKILL_DIR="${ADK_ROOT}/src/skills/dev/caveman"
SKILL_FILE="${SKILL_DIR}/SKILL.md"

step "Downloading caveman skill → src/skills/dev/caveman/SKILL.md ..."
mkdir -p "${SKILL_DIR}"
if curl -fsSL "${SKILL_URL}" -o "${SKILL_FILE}" 2>/dev/null; then
  log "caveman skill downloaded → src/skills/dev/caveman/SKILL.md"
else
  warn "caveman skill download failed — run manually: curl -fsSL ${SKILL_URL} -o ${SKILL_FILE}"
fi

info "Activate caveman mode by saying 'caveman mode' or '/caveman' to the agent."
