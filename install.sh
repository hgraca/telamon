#!/usr/bin/env bash
# =============================================================================
# install.sh — Telamon curl-pipe installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/hgraca/telamon/dev/install.sh | bash
#
# Env vars:
#   TELAMON_DIR    — install directory (default: ~/.telamon)
#   TELAMON_BRANCH — git branch to clone (default: main)
# =============================================================================

set -euo pipefail

# ── Inline color codes ────────────────────────────────────────────────────────
TEXT_BOLD='\033[1m'
TEXT_DIM='\033[2m'
TEXT_RED='\033[0;31m'
TEXT_GREEN='\033[0;32m'
TEXT_YELLOW='\033[0;33m'
TEXT_BLUE='\033[0;34m'
TEXT_MAGENTA='\033[0;35m'
TEXT_WHITE='\033[0;37m'
TEXT_CLEAR='\033[0m'

# ── Logging helpers (self-contained, matching stdout.sh style) ────────────────
log()    { echo -e "  ${TEXT_GREEN}✔${TEXT_CLEAR}  $1"; }
info()   { echo -e "  ${TEXT_BLUE}ℹ${TEXT_CLEAR}  $1"; }
warn()   { echo -e "  ${TEXT_YELLOW}⚠${TEXT_CLEAR}  $1"; }
error()  { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  ERROR: $1"; exit 1; }
header() { echo -e "\n${TEXT_BOLD}${TEXT_BLUE}━━━ $1 ━━━${TEXT_CLEAR}"; }
step()   { echo -e "  ${TEXT_BOLD}→${TEXT_CLEAR}  $1"; }

# ── Config ────────────────────────────────────────────────────────────────────
TELAMON_DIR="${TELAMON_DIR:-${HOME}/.telamon}"
TELAMON_BRANCH="${TELAMON_BRANCH:-main}"
REPO_URL="https://github.com/hgraca/telamon.git"

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  # Header banner
  echo -e ""
  echo -e "${TEXT_BOLD}${TEXT_BLUE}══════════════════════════════════════════${TEXT_CLEAR}"
  echo -e "${TEXT_BOLD}${TEXT_BLUE}Telamon Installer${TEXT_CLEAR}"
  echo -e "${TEXT_BOLD}${TEXT_BLUE}══════════════════════════════════════════${TEXT_CLEAR}"
  echo -e ""

  # ── Check prerequisites ─────────────────────────────────────────────────────
  header "Checking prerequisites"

  if ! command -v git >/dev/null 2>&1; then
    error "git is not installed. Please install git and re-run this script."
  fi
  log "git found: $(git --version)"

  if ! command -v make >/dev/null 2>&1; then
    error "make is not installed. Please install make and re-run this script."
  fi
  log "make found: $(make --version | head -1)"

  # ── Clone or update ─────────────────────────────────────────────────────────
  header "Installing Telamon"

  info "Install directory : ${TELAMON_DIR}"
  info "Branch            : ${TELAMON_BRANCH}"

  if [[ -d "${TELAMON_DIR}" ]]; then
    step "Existing installation found — pulling latest changes..."
    git -C "${TELAMON_DIR}" pull --ff-only
    log "Updated existing installation"
  else
    step "Cloning repository..."
    git clone --branch "${TELAMON_BRANCH}" "${REPO_URL}" "${TELAMON_DIR}"
    log "Cloned ${REPO_URL} (branch: ${TELAMON_BRANCH})"
  fi

  # ── Run make install ─────────────────────────────────────────────────────────
  header "Running setup"

  step "Running make install — this may take a few minutes..."
  # If make install fails, leave the repo intact so the user can fix and retry.
  if ! make -C "${TELAMON_DIR}" install; then
    echo -e ""
    warn "make install failed. The repository is still at ${TELAMON_DIR}."
    warn "Fix the issue above, then run: make -C \"${TELAMON_DIR}\" install"
    exit 1
  fi

  # ── Success banner ───────────────────────────────────────────────────────────
  echo -e ""
  echo -e "${TEXT_BOLD}${TEXT_GREEN}══════════════════════════════════════════${TEXT_CLEAR}"
  echo -e "${TEXT_BOLD}${TEXT_GREEN}  ✔  Telamon installed!${TEXT_CLEAR}"
  echo -e "${TEXT_BOLD}${TEXT_GREEN}══════════════════════════════════════════${TEXT_CLEAR}"
  echo -e ""
  echo -e "  ${TEXT_BOLD}Next steps:${TEXT_CLEAR}"
  echo -e "    ${TEXT_BLUE}telamon init path/to/your-project${TEXT_CLEAR}"
  echo -e "    ${TEXT_BLUE}cd path/to/your-project && opencode${TEXT_CLEAR}"
  echo -e ""
  echo -e "  ${TEXT_BOLD}Other commands:${TEXT_CLEAR}"
  echo -e "    ${TEXT_BLUE}telamon status${TEXT_CLEAR}    # check installation"
  echo -e "    ${TEXT_BLUE}telamon doctor${TEXT_CLEAR}    # health check"
  echo -e "    ${TEXT_BLUE}telamon help${TEXT_CLEAR}      # all commands"
  echo -e ""
}

main "$@"
