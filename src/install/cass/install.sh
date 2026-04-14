#!/usr/bin/env bash
# Install cass (agent session history search) via Homebrew tap, and install
# the cass agent skill globally so all coding agents (including opencode) get
# the robot-mode usage guide.
#
# The initial index is NOT built here — it runs lazily on first `cass search`
# or can be triggered manually with `cass index`.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
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

# ── Install cass agent skill (global, all agents) ─────────────────────────────
# Installs to ~/.agents/skills/cass/ which opencode reads as a global skill.
# The skill teaches agents to use --robot mode, token budgets, health checks,
# and structured error handling — critical for non-interactive use.
step "Installing cass agent skill..."
if command -v npx &>/dev/null; then
  npx --yes skills add https://github.com/dicklesworthstone/coding_agent_session_search \
    --skill cass --global --yes 2>/dev/null \
    && log "cass skill installed → ~/.agents/skills/cass/" \
    || warn "cass skill install failed — run manually: npx skills add https://github.com/dicklesworthstone/coding_agent_session_search --skill cass --global --yes"
else
  warn "npx not found — skipping cass skill install (install Node.js first)"
fi

info "Run 'cass index' to build the session index (skipped here — can be slow)."
