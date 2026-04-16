#!/usr/bin/env bash
# Install Node.js LTS via Homebrew (macOS) or NodeSource (Linux).

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "Node.js"

if command -v node &>/dev/null; then
  skip "Node.js ($(node --version))"; exit 0
fi

OS=$(os.get_os)
if [[ "${OS}" == "macos" ]]; then
  step "Installing Node.js via Homebrew..."
  brew install node
else
  step "Installing Node.js via NodeSource LTS..."
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  apt.install nodejs
fi

log "Node.js $(node --version) installed"
