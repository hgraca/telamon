#!/usr/bin/env bash
# Refresh the caveman skill file from the upstream repository.
# caveman has no binary — it is a skill-only tool, so there is nothing
# to skip when not installed: the skill download always runs.
# Exit codes: 0=success  1=failed

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ADK_ROOT="${ADK_ROOT:-$(cd "${INSTALL_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "caveman"

SKILL_URL="https://raw.githubusercontent.com/JuliusBrussee/caveman/main/caveman/SKILL.md"
SKILL_FILE="${ADK_ROOT}/src/skills/dev/caveman/SKILL.md"

step "Updating caveman skill → src/skills/dev/caveman/SKILL.md ..."
mkdir -p "$(dirname "${SKILL_FILE}")"
curl -fsSL "${SKILL_URL}" -o "${SKILL_FILE}" 2>/dev/null \
  && log "caveman skill updated" \
  || { warn "caveman skill update failed — run manually: curl -fsSL ${SKILL_URL} -o ${SKILL_FILE}"; exit 1; }
