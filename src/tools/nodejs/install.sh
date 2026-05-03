#!/usr/bin/env bash
# Install Node.js LTS via Homebrew (macOS) or NodeSource (Linux).

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "Node.js"

if command -v node &>/dev/null; then
  skip "Node.js ($(node --version))"
else
  OS=$(os.get_os)
  if [[ "${OS}" == "macos" ]]; then
    step "Installing Node.js via Homebrew..."
    brew install node
  else
    step "Installing Node.js via NodeSource LTS..."
    setup_script=$(mktemp)
    trap 'rm -f "${setup_script}"' EXIT
    curl -fsSL https://deb.nodesource.com/setup_lts.x -o "${setup_script}"
    sudo -E bash "${setup_script}"
    apt.install nodejs
  fi
  log "Node.js $(node --version) installed"
fi

# Clean stale npm temp dirs from previous interrupted installs (ENOTEMPTY fix)
# Runs regardless of whether Node was just installed or already existed
if command -v npm &>/dev/null; then
  NPM_GLOBAL_PREFIX="$(npm prefix -g 2>/dev/null || echo "")"
  if [[ -n "${NPM_GLOBAL_PREFIX}" && -d "${NPM_GLOBAL_PREFIX}/lib/node_modules" ]]; then
    find "${NPM_GLOBAL_PREFIX}/lib/node_modules" -maxdepth 1 -name ".*" -type d -mmin +5 -exec rm -rf {} + 2>/dev/null || true
  fi
fi
