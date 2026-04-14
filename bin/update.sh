#!/usr/bin/env bash
# =============================================================================
# bin/update.sh
# Upgrade all ADK-managed tools to their latest versions.
#
# Usage:
#   bin/update.sh
#   make update
# =============================================================================

set -euo pipefail

ADK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_PATH="${ADK_ROOT}/src/install"
export INSTALL_PATH ADK_ROOT

# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:$PATH"

echo -e "\n${TEXT_BOLD}${TEXT_BLUE}"
echo "  ╔═════════════════════════════════════════════════╗"
echo "  ║   AI Agentic Development Kit — Update          ║"
echo "  ╚═════════════════════════════════════════════════╝"
echo -e "${TEXT_CLEAR}"

FAILED=0
SKIPPED=0

_fail()    { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  $1"; FAILED=$((FAILED + 1)); }
_skip_tool() { echo -e "  ${TEXT_DIM}–  $1 (not installed — skipping)${TEXT_CLEAR}"; SKIPPED=$((SKIPPED + 1)); }

# ── Homebrew ───────────────────────────────────────────────────────────────────
header "Package managers"

if command -v brew &>/dev/null; then
  step "Updating Homebrew..."
  brew update --quiet 2>/dev/null && log "Homebrew updated" || _fail "Homebrew update failed"
else
  _skip_tool "Homebrew"
fi

# ── Docker images ──────────────────────────────────────────────────────────────
header "Docker images"

if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
  step "Pulling latest Docker images..."
  (cd "${ADK_ROOT}" && docker compose pull --quiet 2>/dev/null) \
    && log "Docker images updated" \
    || _fail "Docker image pull failed"
else
  _skip_tool "Docker (not running)"
fi

# ── opencode ───────────────────────────────────────────────────────────────────
header "opencode"

if command -v opencode &>/dev/null; then
  step "Upgrading opencode via npm..."
  npm install -g opencode-ai --quiet 2>/dev/null \
    && log "opencode → $(opencode --version 2>/dev/null || echo 'updated')" \
    || _fail "opencode upgrade failed — try: npm install -g opencode-ai"
else
  _skip_tool "opencode"
fi

# ── Ogham MCP ──────────────────────────────────────────────────────────────────
header "Ogham MCP"

if command -v ogham &>/dev/null; then
  step "Upgrading ogham-mcp via uv..."
  uv tool upgrade ogham-mcp 2>/dev/null \
    && log "ogham → $(ogham --version 2>/dev/null || echo 'updated')" \
    || _fail "ogham upgrade failed — try: uv tool upgrade ogham-mcp"
else
  _skip_tool "ogham"
fi

# ── Graphify ───────────────────────────────────────────────────────────────────
header "Graphify"

if command -v graphify &>/dev/null; then
  step "Upgrading graphifyy via uv..."
  uv tool upgrade graphifyy 2>/dev/null \
    && log "graphify → $(graphify --version 2>/dev/null || echo 'updated')" \
    || _fail "graphify upgrade failed — try: uv tool upgrade graphifyy"
else
  _skip_tool "graphify"
fi

# ── cass ───────────────────────────────────────────────────────────────────────
header "cass"

if command -v cass &>/dev/null; then
  step "Upgrading cass via Homebrew..."
  # brew upgrade exits non-zero when package is already at the latest version;
  # treat that as success.
  brew upgrade dicklesworthstone/tap/cass 2>/dev/null \
    || brew upgrade cass 2>/dev/null \
    || true
  log "cass → $(cass --version 2>/dev/null || echo 'updated')"

  step "Updating cass agent skill..."
  if command -v npx &>/dev/null; then
    npx --yes skills update cass --global --yes 2>/dev/null \
      && log "cass skill updated → ~/.agents/skills/cass/" \
      || warn "cass skill update failed — run manually: npx skills update cass --global --yes"
  else
    warn "npx not found — skipping cass skill update"
  fi
else
  _skip_tool "cass"
fi

# ── RTK ───────────────────────────────────────────────────────────────────────
header "RTK"

if command -v rtk &>/dev/null; then
  step "Upgrading RTK via Homebrew..."
  brew upgrade rtk-ai/tap/rtk 2>/dev/null \
    || brew upgrade rtk 2>/dev/null \
    || true
  log "rtk → $(rtk --version 2>/dev/null || echo 'updated')"
else
  _skip_tool "rtk"
fi

# ── Node.js global packages ───────────────────────────────────────────────────
header "Node.js tools"

if command -v npm &>/dev/null; then
  step "Updating npm global packages..."
  npm update -g --quiet 2>/dev/null \
    && log "npm global packages updated" \
    || _fail "npm global update failed"
else
  _skip_tool "npm"
fi

# ── Summary ────────────────────────────────────────────────────────────────────
echo
echo -e "${TEXT_BOLD}${TEXT_GREEN}══════════════════════════════════════════${TEXT_CLEAR}"
echo -e "${TEXT_BOLD}  Update complete${TEXT_CLEAR}"
echo -e "${TEXT_BOLD}${TEXT_GREEN}══════════════════════════════════════════${TEXT_CLEAR}"
echo
[[ "${SKIPPED}" -gt 0 ]] && echo -e "  ${TEXT_DIM}–  Skipped ${SKIPPED} tool(s) not installed on this machine${TEXT_CLEAR}"
[[ "${FAILED}"  -gt 0 ]] && echo -e "  ${TEXT_RED}✖  ${FAILED} upgrade(s) failed — see above for details${TEXT_CLEAR}"
[[ "${FAILED}"  -eq 0 ]] && echo -e "  ${TEXT_GREEN}✔  All installed tools are up to date${TEXT_CLEAR}"
echo

[[ "${FAILED}" -gt 0 ]] && exit 1 || exit 0
