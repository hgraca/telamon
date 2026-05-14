#!/usr/bin/env bash
# Ensure git is installed — required by Telamon for all VCS operations.
# Most systems ship git pre-installed; this is a safety check.

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "Git"

if command -v git &>/dev/null; then
  skip "git ($(git --version 2>/dev/null | head -1 || echo 'installed'))"
else
  OS=$(os.get_os)
  if [[ "${OS}" == "macos" ]]; then
    step "Installing git via Homebrew..."
    brew install git
  else
    step "Installing git via apt..."
    apt.install git
  fi
  log "git installed ($(git --version 2>/dev/null | head -1))"
fi