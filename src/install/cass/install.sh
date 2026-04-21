#!/usr/bin/env bash
# Install cass (agent session history search) via Homebrew tap, and download
# the upstream cass SKILL.md into src/skills/memory/_tools/cass/ so it is available
# to all initialized projects via the .opencode/skills/telamon symlink.
#
# The initial index is built after install (can take several minutes on first run).

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

# ── Download cass agent skill into src/skills/memory/_tools/cass/ ────────────────────
# The skill teaches agents to use --robot mode, token budgets, health checks,
# and structured error handling. It reaches all initialized projects via the
# .opencode/skills/telamon → src/skills symlink created by bin/init.sh.
SKILL_URL="https://raw.githubusercontent.com/dicklesworthstone/coding_agent_session_search/main/SKILL.md"
SKILL_DIR="${TELAMON_ROOT}/src/skills/memory/_tools/cass"
SKILL_FILE="${SKILL_DIR}/SKILL.md"

step "Downloading cass skill → src/skills/memory/_tools/cass/SKILL.md ..."
mkdir -p "${SKILL_DIR}"
if curl -fsSL "${SKILL_URL}" -o "${SKILL_FILE}" 2>/dev/null; then
  log "cass skill downloaded → src/skills/memory/_tools/cass/SKILL.md"
else
  warn "cass skill download failed — run manually: curl -fsSL ${SKILL_URL} -o ${SKILL_FILE}"
fi

# Remove the global skill if it was previously installed there by mistake
if [[ -d "${HOME}/.agents/skills/cass" ]]; then
  step "Removing stale global cass skill from ~/.agents/skills/cass/ ..."
  rm -rf "${HOME}/.agents/skills/cass"
  log "Removed ~/.agents/skills/cass/"
fi

# Index strategy:
#   - First install (no DB): block and build synchronously — cass is unusable without it
#   - DB exists but unhealthy: rebuild in background — scheduled job will also catch it
#   - DB exists and healthy: skip — the every-30-min scheduled job keeps it fresh
_cass_db="${HOME}/.local/share/coding-agent-search/agent_search.db"
if command -v cass &>/dev/null; then
  if [[ ! -f "${_cass_db}" ]]; then
    step "Building initial cass index (first install — this may take a few minutes)..."
    _cass_out=$(CODING_AGENT_SEARCH_NO_UPDATE_PROMPT=1 cass index --json 2>&1)
    _cass_exit=$?
    if [[ $_cass_exit -eq 0 ]]; then
      log "cass index built"
    elif echo "$_cass_out" | grep -q '"kind":"index_busy"\|"kind": "index_busy"'; then
      skip "cass index already in progress (scheduled job) — skipping redundant build"
    else
      warn "cass index failed — retry with 'cass index' later"
    fi
  elif ! CODING_AGENT_SEARCH_NO_UPDATE_PROMPT=1 cass health --json >/dev/null 2>&1; then
    step "cass index unhealthy — rebuilding in background (non-blocking)..."
    CODING_AGENT_SEARCH_NO_UPDATE_PROMPT=1 cass index --json >/dev/null 2>&1 &
    log "cass index running in background (PID $!)"
  else
    skip "cass index (healthy — scheduled job maintains freshness)"
  fi
else
  warn "cass not found — skipping index"
fi
