#!/usr/bin/env bash
# Install Python 3 and uv (fast Python package manager).

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "Python & uv"

OS=$(os.get_os)

if ! command -v python3 &>/dev/null; then
  if [[ "${OS}" == "macos" ]]; then
    step "Installing Python 3 via Homebrew..."
    brew install python3
  else
    step "Installing Python 3 via apt..."
    apt.install python3 python3-pip python3-venv
  fi
  log "Python 3 installed"
else
  skip "Python 3 ($(python3 --version))"
fi

if ! command -v uv &>/dev/null; then
  step "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
  log "uv installed"
else
  skip "uv ($(uv --version))"
fi
