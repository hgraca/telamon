#!/usr/bin/env bash
# Update cass via Homebrew and refresh its skill file.
# Exit codes: 0=success  1=failed  2=not-installed (skipped)

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ADK_ROOT="${ADK_ROOT:-$(cd "${INSTALL_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "cass"

if ! command -v cass &>/dev/null; then
  echo -e "  ${TEXT_DIM}–  cass (not installed — skipping)${TEXT_CLEAR}"
  exit 2
fi

_failed=0

step "Upgrading cass via Homebrew..."
# brew upgrade exits non-zero when the package is already at the latest version;
# treat that as success.
brew upgrade dicklesworthstone/tap/cass 2>/dev/null \
  || brew upgrade cass 2>/dev/null \
  || true
log "cass → $(cass --version 2>/dev/null || echo 'updated')"

step "Updating cass skill → src/skills/memory/cass/SKILL.md ..."
SKILL_URL="https://raw.githubusercontent.com/dicklesworthstone/coding_agent_session_search/main/SKILL.md"
SKILL_FILE="${ADK_ROOT}/src/skills/memory/cass/SKILL.md"
mkdir -p "$(dirname "${SKILL_FILE}")"
if curl -fsSL "${SKILL_URL}" -o "${SKILL_FILE}" 2>/dev/null; then
  log "cass skill updated"
else
  warn "cass skill update failed — run manually: curl -fsSL ${SKILL_URL} -o ${SKILL_FILE}"
  _failed=1
fi

[[ "${_failed}" -eq 0 ]] || exit 1
