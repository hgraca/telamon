#!/usr/bin/env bash
# Refresh the caveman skill file from the upstream repository.
# caveman has no binary — it is a skill-only tool, so there is nothing
# to skip when not installed: the skill download always runs.
# Exit codes: 0=success  1=failed

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TELAMON_ROOT="${TELAMON_ROOT:-$(cd "${TOOLS_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "caveman"

SKILL_URL="https://raw.githubusercontent.com/JuliusBrussee/caveman/main/caveman/SKILL.md"
SKILL_FILE="${TELAMON_ROOT}/src/skills/workflow/caveman/SKILL.md"

step "Updating caveman skill → src/skills/workflow/caveman/SKILL.md ..."
mkdir -p "$(dirname "${SKILL_FILE}")"
curl -fsSL "${SKILL_URL}" -o "${SKILL_FILE}" 2>/dev/null \
  && log "caveman skill updated" \
  || { warn "caveman skill update failed — run manually: curl -fsSL ${SKILL_URL} -o ${SKILL_FILE}"; exit 1; }
