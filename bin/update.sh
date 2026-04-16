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

# ── ADK repo self-update ───────────────────────────────────────────────────────
header "ADK repo"

_STASHED=0
if git -C "${ADK_ROOT}" diff --quiet && git -C "${ADK_ROOT}" diff --cached --quiet; then
  skip "stash (nothing to stash)"
else
  step "Stashing local changes..."
  git -C "${ADK_ROOT}" stash push --include-untracked -m "update.sh auto-stash" \
    && log "Changes stashed" \
    && _STASHED=1 \
    || { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  git stash failed — aborting rebase"; FAILED=$((FAILED + 1)); }
fi

if [[ "${FAILED}" -eq 0 ]]; then
  step "Rebasing onto origin..."
  git -C "${ADK_ROOT}" pull --rebase \
    && log "Rebased onto $(git -C "${ADK_ROOT}" rev-parse --abbrev-ref HEAD)" \
    || { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  git pull --rebase failed — resolve conflicts, then run 'git stash pop' if needed"; FAILED=$((FAILED + 1)); }
fi

if [[ "${_STASHED}" -eq 1 && "${FAILED}" -eq 0 ]]; then
  step "Restoring stashed changes..."
  git -C "${ADK_ROOT}" stash pop \
    && log "Stash restored" \
    || { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  git stash pop failed — resolve conflicts manually"; FAILED=$((FAILED + 1)); }
fi

# ── Per-app updates ────────────────────────────────────────────────────────────
# Each src/install/<app>/update.sh exits:
#   0 — success
#   1 — failure
#   2 — tool not installed (skip)
UPDATE_APPS=(homebrew docker opencode ogham graphify cass caveman rtk nodejs qmd)

for _app in "${UPDATE_APPS[@]}"; do
  _script="${INSTALL_PATH}/${_app}/update.sh"
  if [[ ! -f "${_script}" ]]; then
    warn "No update.sh for ${_app} — skipping"
    continue
  fi
  bash "${_script}" && true   # suppress errexit for exit-code capture
  _rc=$?
  case "${_rc}" in
    0) : ;;                               # success — nothing to tally
    2) SKIPPED=$((SKIPPED + 1)) ;;       # not installed
    *) FAILED=$((FAILED + 1)) ;;         # any other non-zero = failure
  esac
done

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
