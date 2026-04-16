#!/usr/bin/env bash
# Install cass (agent session history search) via Homebrew tap, and download
# the upstream cass SKILL.md into src/skills/memory/cass/ so it is available
# to all initialized projects via the .opencode/skills/telamon symlink.
#
# The initial index is NOT built here — it runs lazily on first `cass search`
# or can be triggered manually with `cass index`.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TELAMON_ROOT="${TELAMON_ROOT:-$(cd "${INSTALL_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

# ── Install binary ─────────────────────────────────────────────────────────────
header "cass (agent session search)"

if ! command -v cass &>/dev/null; then
  step "Installing cass via Homebrew..."
  brew tap dicklesworthstone/tap 2>/dev/null || true
  brew install dicklesworthstone/tap/cass
  log "cass installed"
else
  skip "cass ($(cass --version 2>/dev/null || echo 'installed'))"
fi

# ── Download cass agent skill into src/skills/memory/cass/ ────────────────────
# The skill teaches agents to use --robot mode, token budgets, health checks,
# and structured error handling. It reaches all initialized projects via the
# .opencode/skills/telamon → src/skills symlink created by bin/init.sh.
SKILL_URL="https://raw.githubusercontent.com/dicklesworthstone/coding_agent_session_search/main/SKILL.md"
SKILL_DIR="${TELAMON_ROOT}/src/skills/memory/cass"
SKILL_FILE="${SKILL_DIR}/SKILL.md"

step "Downloading cass skill → src/skills/memory/cass/SKILL.md ..."
mkdir -p "${SKILL_DIR}"
if curl -fsSL "${SKILL_URL}" -o "${SKILL_FILE}" 2>/dev/null; then
  log "cass skill downloaded → src/skills/memory/cass/SKILL.md"
else
  warn "cass skill download failed — run manually: curl -fsSL ${SKILL_URL} -o ${SKILL_FILE}"
fi

# Remove the global skill if it was previously installed there by mistake
if [[ -d "${HOME}/.agents/skills/cass" ]]; then
  step "Removing stale global cass skill from ~/.agents/skills/cass/ ..."
  rm -rf "${HOME}/.agents/skills/cass"
  log "Removed ~/.agents/skills/cass/"
fi

info "Run 'cass index' to build the session index (skipped here — can be slow)."
