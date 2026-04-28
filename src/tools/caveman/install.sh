#!/usr/bin/env bash
# Download the caveman skill (token-efficient communication mode) into
# src/skills/workflow/caveman/ so it is available to all initialized projects
# via the .opencode/skills/telamon symlink created by bin/init.sh.
#
# caveman has no binary — it is a skill-only tool.

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TELAMON_ROOT="${TELAMON_ROOT:-$(cd "${TOOLS_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "caveman (token-efficient communication skill)"

SKILL_URL="https://raw.githubusercontent.com/JuliusBrussee/caveman/main/caveman/SKILL.md"
SKILL_DIR="${TELAMON_ROOT}/src/skills/workflow/caveman"
SKILL_FILE="${SKILL_DIR}/SKILL.md"

step "Downloading caveman skill → src/skills/workflow/caveman/SKILL.md ..."
mkdir -p "${SKILL_DIR}"
if curl -fsSL "${SKILL_URL}" -o "${SKILL_FILE}" 2>/dev/null; then
  log "caveman skill downloaded → src/skills/workflow/caveman/SKILL.md"
else
  warn "caveman skill download failed — run manually: curl -fsSL ${SKILL_URL} -o ${SKILL_FILE}"
fi

info "Activate caveman mode by saying 'caveman mode' or '/caveman' to the agent."
