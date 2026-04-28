#!/usr/bin/env bash
# Install Homebrew (macOS) or Linuxbrew (Linux).

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "Homebrew"

if command -v brew &>/dev/null; then
  skip "Homebrew"; exit 0
fi

OS=$(os.get_os)
case "${OS}" in
  macos)
    # shellcheck disable=SC1091
    . "${TOOLS_PATH}/homebrew/install.macos.sh"
    ;;
  linux)
    # shellcheck disable=SC1091
    . "${TOOLS_PATH}/homebrew/install.linux.sh"
    ;;
  *)
    error "Unsupported OS: ${OS}. Supports macOS and Linux."
    ;;
esac

# Add Homebrew to PATH for this session
if [[ "${OS}" == "macos" ]]; then
  [[ -f /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
  [[ -f /usr/local/bin/brew   ]] && eval "$(/usr/local/bin/brew shellenv)"
else
  [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]] && \
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
fi

log "Homebrew installed"
